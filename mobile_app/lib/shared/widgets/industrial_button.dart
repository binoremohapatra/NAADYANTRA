import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

enum IndustrialButtonVariant { primary, secondary, danger, ghost }

/// Industrial Tactile Button with Spring Press Animation
class IndustrialButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final IndustrialButtonVariant variant;
  final double? width;
  final double height;

  const IndustrialButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = IndustrialButtonVariant.primary,
    this.width,
    this.height = 48,
  });

  @override
  State<IndustrialButton> createState() => _IndustrialButtonState();
}

class _IndustrialButtonState extends State<IndustrialButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  AnimationController? _glowController;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.955).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );

    if (widget.variant == IndustrialButtonVariant.primary) {
      _glowController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat(reverse: true);
      _glowAnimation = Tween<double>(begin: 0.22, end: 0.45).animate(
        CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void didUpdateWidget(covariant IndustrialButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.variant == IndustrialButtonVariant.primary &&
        _glowController == null) {
      _glowController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat(reverse: true);
      _glowAnimation = Tween<double>(begin: 0.22, end: 0.45).animate(
        CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
      );
    } else if (widget.variant != IndustrialButtonVariant.primary &&
        _glowController != null) {
      _glowController?.dispose();
      _glowController = null;
      _glowAnimation = null;
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _glowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReduced = MotionTokens.isReducedMotion(context);

    Color bg;
    Color fg;
    BorderSide border;

    switch (widget.variant) {
      case IndustrialButtonVariant.primary:
        bg = AppColors.burntOrange;
        fg = AppColors.pureWhite;
        border = BorderSide.none;
        break;
      case IndustrialButtonVariant.secondary:
        bg = isDark ? AppColors.darkSurfaceElevated : AppColors.pureWhite;
        fg = isDark ? AppColors.darkTextPrimary : AppColors.carbon;
        border = BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.warmStone,
          width: 1.5,
        );
        break;
      case IndustrialButtonVariant.danger:
        bg = AppColors.alertDanger.withValues(alpha: 0.12);
        fg = AppColors.alertDanger;
        border = const BorderSide(color: AppColors.alertDanger, width: 1.2);
        break;
      case IndustrialButtonVariant.ghost:
        bg = Colors.transparent;
        fg = isDark ? AppColors.darkTextSecondary : AppColors.warmGraphite;
        border = BorderSide.none;
        break;
    }

    final childWidget = widget.isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    final isEnabled = widget.onPressed != null && !widget.isLoading;

    Widget buildButtonBody(double glowAlpha) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: isEnabled ? bg : bg.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(9),
          border: Border.fromBorderSide(border),
          boxShadow:
              (widget.variant == IndustrialButtonVariant.primary && isEnabled)
              ? [
                  BoxShadow(
                    color: AppColors.burntOrange.withValues(alpha: glowAlpha),
                    blurRadius: 12,
                    spreadRadius: glowAlpha > 0.3 ? 1.0 : 0.0,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? widget.onPressed : null,
            onHighlightChanged: isEnabled && !isReduced
                ? (highlighted) {
                    if (highlighted) {
                      _pressController.forward();
                    } else {
                      _pressController.reverse();
                    }
                  }
                : null,
            borderRadius: BorderRadius.circular(9),
            splashColor: widget.variant == IndustrialButtonVariant.primary
                ? AppColors.darkBurntOrange.withValues(alpha: 0.3)
                : AppColors.burntOrange.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(child: childWidget),
            ),
          ),
        ),
      );
    }

    Widget content;
    if (_glowAnimation != null && !isReduced) {
      content = AnimatedBuilder(
        animation: _glowAnimation!,
        builder: (context, _) => buildButtonBody(_glowAnimation!.value),
      );
    } else {
      content = buildButtonBody(0.28);
    }

    if (isReduced) {
      return content;
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnimation.value, child: child),
      child: content,
    );
  }
}
