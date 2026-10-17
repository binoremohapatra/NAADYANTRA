import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

// ──────────────────────────────────────────────────────────────────────────────
// InteractiveMetricCard
//
// A tappable diagnostic metric surface that opens a contextual bottom sheet
// with full detail. Replaces the static MetricReadout for home screen metrics.
//
// Interaction contract:
//   Tap → spring press → HapticFeedback.selectionClick → bottom sheet opens
//   Bottom sheet → shows sensor name, value, unit, last update, meaning
//   Dismiss → swipe down or tap scrim
//   Loading → branded ShimmerBox skeleton
//   Error / no-data → explicit empty state clearly labeled
// ──────────────────────────────────────────────────────────────────────────────

class InteractiveMetricCard extends StatefulWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color? accentColor;
  final String? explanation;
  final String? lastUpdated;
  final VoidCallback? onTap; // override: navigate instead of sheet

  const InteractiveMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    this.accentColor,
    this.explanation,
    this.lastUpdated,
    this.onTap,
  });

  @override
  State<InteractiveMetricCard> createState() => _InteractiveMetricCardState();
}

class _InteractiveMetricCardState extends State<InteractiveMetricCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _borderAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: MotionTokens.durationInstant,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic));
    _borderAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    _showDetailSheet();
  }

  void _showDetailSheet() {
    final accent = widget.accentColor ?? AppColors.burntOrange;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MetricDetailSheet(
        label: widget.label,
        value: widget.value,
        unit: widget.unit,
        icon: widget.icon,
        accent: accent,
        explanation: widget.explanation,
        lastUpdated: widget.lastUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReduced = MotionTokens.isReducedMotion(context);
    final accent = widget.accentColor ?? AppColors.burntOrange;

    // Parse numeric for animated counter
    final numVal = double.tryParse(
      widget.value.replaceAll(RegExp(r'[^\d.]'), ''),
    );
    final hasDecimal = widget.value.contains('.');

    Widget valueWidget;
    if (numVal != null && !isReduced) {
      valueWidget = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: numVal * 0.5, end: numVal),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutExpo,
        builder: (_, val, child) => Text(
          hasDecimal ? val.toStringAsFixed(1) : val.toInt().toString(),
          style: AppTypography.spaceGrotesk(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: isDark ? AppColors.darkTextPrimary : AppColors.carbon,
          ),
          maxLines: 1,
        ),
      );
    } else {
      valueWidget = Text(
        widget.value,
        style: AppTypography.spaceGrotesk(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: isDark ? AppColors.darkTextPrimary : AppColors.carbon,
        ),
        maxLines: 1,
      );
    }

    final card = AnimatedBuilder(
      animation: _pressCtrl,
      builder: (_, child) {
        final borderAlpha = _borderAnim.value * 0.5;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color.lerp(
                isDark ? AppColors.darkBorder : AppColors.warmStone,
                accent,
                borderAlpha,
              )!,
              width: 1.0 + _borderAnim.value * 0.5,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(
                        alpha: 0.04 + _borderAnim.value * 0.08,
                      ),
                      blurRadius: 8 + _borderAnim.value * 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(widget.icon, size: 13, color: accent),
              ),
              Icon(
                Icons.arrow_outward_rounded,
                size: 13,
                color:
                    (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.warmGraphite)
                        .withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.label.toUpperCase(),
            style: AppTypography.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.warmGraphite,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: valueWidget),
              if (widget.unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  widget.unit!,
                  style: AppTypography.inter(
                    fontSize: 11,
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

    if (isReduced) {
      return InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: card,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _MetricDetailSheet — bottom sheet with full metric context
// ──────────────────────────────────────────────────────────────────────────────

class _MetricDetailSheet extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color accent;
  final String? explanation;
  final String? lastUpdated;

  const _MetricDetailSheet({
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    required this.accent,
    this.explanation,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.darkSurface : AppColors.pureWhite;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.warmStone,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.carbon.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Metric header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.warmGraphite,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value,
                            style: AppTypography.spaceGrotesk(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.carbon,
                            ),
                          ),
                          if (unit != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              unit!,
                              style: AppTypography.inter(
                                fontSize: 14,
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
                ),
              ],
            ),

            if (lastUpdated != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.industrialIvory,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.update_rounded,
                      size: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.warmGraphite,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Updated $lastUpdated',
                      style: AppTypography.mono(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.warmGraphite,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (explanation != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        explanation!,
                        style: AppTypography.inter(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.warmGraphite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
