import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

enum StatusType {
  online,
  offline,
  active,
  completed,
  danger,
  caution,
  ok,
  neutral,
}

class StatusPill extends StatefulWidget {
  final String label;
  final StatusType type;
  final bool showDot;

  const StatusPill({
    super.key,
    required this.label,
    this.type = StatusType.neutral,
    this.showDot = true,
  });

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final shouldAnimate =
        widget.showDot &&
        (widget.type == StatusType.online ||
            widget.type == StatusType.active ||
            widget.type == StatusType.danger ||
            widget.type == StatusType.caution ||
            widget.type == StatusType.ok);

    if (shouldAnimate) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate =
        widget.showDot &&
        (widget.type == StatusType.online ||
            widget.type == StatusType.active ||
            widget.type == StatusType.danger ||
            widget.type == StatusType.caution ||
            widget.type == StatusType.ok);

    if (shouldAnimate && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!shouldAnimate && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReduced = MotionTokens.isReducedMotion(context);

    Color bg;
    Color border;
    Color text;
    Color dot;

    switch (widget.type) {
      case StatusType.online:
      case StatusType.ok:
      case StatusType.active:
        bg = AppColors.alertOk.withValues(alpha: 0.1);
        border = AppColors.alertOk.withValues(alpha: 0.3);
        text = AppColors.alertOk;
        dot = AppColors.alertOk;
        break;
      case StatusType.danger:
        bg = AppColors.alertDanger.withValues(alpha: 0.1);
        border = AppColors.alertDanger.withValues(alpha: 0.3);
        text = AppColors.alertDanger;
        dot = AppColors.alertDanger;
        break;
      case StatusType.caution:
        bg = AppColors.alertCaution.withValues(alpha: 0.12);
        border = AppColors.alertCaution.withValues(alpha: 0.35);
        text = AppColors.alertCaution;
        dot = AppColors.alertCaution;
        break;
      case StatusType.completed:
        bg = AppColors.burntOrange.withValues(alpha: 0.1);
        border = AppColors.burntOrange.withValues(alpha: 0.3);
        text = AppColors.darkBurntOrange;
        dot = AppColors.burntOrange;
        break;
      case StatusType.offline:
      case StatusType.neutral:
        bg = AppColors.softSand.withValues(alpha: 0.3);
        border = AppColors.warmStone;
        text = AppColors.warmGraphite;
        dot = AppColors.warmGraphite;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showDot) ...[
            if (isReduced)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              )
            else
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) => Container(
                  width: 8,
                  height: 8,
                  alignment: Alignment.center,
                  child: Container(
                    width: 6 * _pulseAnimation.value,
                    height: 6 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: dot.withValues(
                            alpha: (_pulseAnimation.value - 0.7).clamp(
                              0.0,
                              0.6,
                            ),
                          ),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 6),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
