import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// [TimelineNode] — Precision industrial chronological timeline item.
/// Connects events or sessions vertically with a technical datum stem,
/// a status node beacon, and a tactile content container.
class TimelineNode extends StatelessWidget {
  final Widget child;
  final bool isFirst;
  final bool isLast;
  final Color nodeColor;
  final IconData? nodeIcon;
  final String? timeLabel;
  final String? tag;
  final VoidCallback? onTap;

  const TimelineNode({
    super.key,
    required this.child,
    this.isFirst = false,
    this.isLast = false,
    this.nodeColor = AppColors.burntOrange,
    this.nodeIcon,
    this.timeLabel,
    this.tag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stemColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : AppColors.warmStone.withValues(alpha: 0.9);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Vertical stem & Node indicator ──
          SizedBox(
            width: 44,
            child: Column(
              children: [
                // Upper stem
                Expanded(
                  flex: isFirst ? 0 : 1,
                  child: Container(
                    width: 2,
                    height: isFirst ? 8 : null,
                    color: isFirst ? Colors.transparent : stemColor,
                  ),
                ),
                // Center node beacon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: nodeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: nodeColor.withValues(alpha: 0.8),
                      width: 1.8,
                    ),
                  ),
                  child: Center(
                    child: nodeIcon != null
                        ? Icon(nodeIcon, size: 14, color: nodeColor)
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: nodeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),
                // Lower stem
                Expanded(
                  flex: isLast ? 0 : 2,
                  child: Container(
                    width: 2,
                    height: isLast ? 8 : null,
                    color: isLast ? Colors.transparent : stemColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Main Content Column ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Optional metadata header line
                  if (timeLabel != null || tag != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 6),
                      child: Row(
                        children: [
                          if (timeLabel != null)
                            Text(
                              timeLabel!,
                              style: AppTypography.mono(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.warmGraphite,
                              ),
                            ),
                          if (timeLabel != null && tag != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                '·',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.warmStone,
                                ),
                              ),
                            ),
                          if (tag != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceElevated
                                    : AppColors.warmStone.withValues(
                                        alpha: 0.4,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag!,
                                style: AppTypography.mono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
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
                  // Content widget with optional tap
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
