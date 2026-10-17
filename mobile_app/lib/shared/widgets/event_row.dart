import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';
import '../../shared/models/event.dart';
import '../backgrounds/naadyantra_animated_background.dart';

// ──────────────────────────────────────────────────────────────────────────────
// EventRow — tappable event list item
//
// Interaction contract:
//   Tap → haptic + spring press → detail bottom sheet
//   Sheet → severity badge, timestamp, device ID, diagnostic context
//   Long press → show event ID in snack bar
//   Dismiss → swipe or tap scrim
// ──────────────────────────────────────────────────────────────────────────────

/// Derives a severity label from event fields.
String _eventSeverity(Event event) {
  if (event.alert != null && event.alert!.isNotEmpty) {
    return 'critical';
  }
  if (event.leakProbability != null && event.leakProbability! > 0.6) {
    return 'warning';
  }
  if (event.hazardState != null && event.hazardState! >= 2) {
    return 'warning';
  }
  return 'info';
}

/// Derives a human-readable title from event fields.
String _eventTitle(Event event) {
  if (event.eventName != null && event.eventName!.isNotEmpty) {
    return event.eventName!;
  }
  if (event.alert != null && event.alert!.isNotEmpty) {
    return event.alert!;
  }
  if (event.modelLabel != null && event.modelLabel!.isNotEmpty) {
    return event.modelLabel!;
  }
  if (event.hazardStateLabel != null) {
    return event.hazardStateLabel!;
  }
  return event.eventKind.replaceAll('_', ' ').toUpperCase();
}

class EventRow extends StatefulWidget {
  final Event event;
  final bool showDivider;

  const EventRow({super.key, required this.event, this.showDivider = true});

  @override
  State<EventRow> createState() => _EventRowState();
}

class _EventRowState extends State<EventRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: MotionTokens.durationInstant,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return AppColors.alertDanger;
      case 'warning':
        return AppColors.alertCaution;
      case 'info':
        return AppColors.alertOk;
      default:
        return AppColors.warmGraphite;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.error_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'info':
        return Icons.info_rounded;
      default:
        return Icons.circle_rounded;
    }
  }

  String _formatTs(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM HH:mm').format(ts);
  }

  void _onTap() {
    HapticFeedback.selectionClick();
    _showDetailSheet();
  }

  void _showDetailSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _EventDetailSheet(event: widget.event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReduced = MotionTokens.isReducedMotion(context);
    final severity = _eventSeverity(widget.event);
    final title = _eventTitle(widget.event);
    final sColor = _severityColor(severity);
    final sIcon = _severityIcon(severity);
    final timestamp = _formatTs(widget.event.serverTimestamp);

    Widget rowContent = GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        if (!isReduced) _pressCtrl.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _pressCtrl.reverse();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _pressCtrl.reverse();
      },
      onTap: _onTap,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event ID: ${widget.event.id}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: MotionTokens.durationInstant,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: _isPressed
            ? (isDark
                  ? AppColors.darkSurfaceElevated
                  : AppColors.warmStone.withValues(alpha: 0.3))
            : Colors.transparent,
        child: Row(
          children: [
            // Severity indicator
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(sIcon, size: 18, color: sColor),
                if (widget.showDivider) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 1.5,
                    height: 16,
                    color: sColor.withValues(alpha: 0.25),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.carbon,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: sColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          severity.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: sColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.warmGraphite,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timestamp,
                        style: AppTypography.mono(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.warmGraphite,
                        ),
                      ),
                      Text(
                        ' · ${widget.event.deviceId}',
                        style: AppTypography.inter(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.warmGraphite,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color:
                  (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.warmGraphite)
                      .withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );

    if (isReduced) return rowContent;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, child) =>
          Transform.scale(scale: _scaleAnim.value, child: child),
      child: rowContent,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _EventDetailSheet — full event context bottom sheet
// ──────────────────────────────────────────────────────────────────────────────

class _EventDetailSheet extends StatelessWidget {
  final Event event;

  const _EventDetailSheet({required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final severity = _eventSeverity(event);
    final title = _eventTitle(event);

    Color sColor;
    switch (severity) {
      case 'critical':
        sColor = AppColors.alertDanger;
        break;
      case 'warning':
        sColor = AppColors.alertCaution;
        break;
      default:
        sColor = AppColors.alertOk;
    }

    final sheetBg = isDark ? AppColors.darkSurface : AppColors.pureWhite;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.warmStone,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.carbon.withValues(alpha: isDark ? 0.4 : 0.07),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: NaadyantraAnimatedBackground(
          kind: NaadyantraBackgroundKind.eventDetails,
          lightScrimOpacity: 0.90,
          darkScrimOpacity: 0.74,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.warmStone,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Severity badge + title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: sColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: sColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        severity.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: sColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.carbon,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                ),
                const SizedBox(height: 16),

                // Detail rows
                _DetailRow(
                  icon: Icons.access_time_rounded,
                  label: 'Timestamp',
                  value: DateFormat('d MMM yyyy, HH:mm:ss')
                      .format(event.serverTimestamp),
                  isDark: isDark,
                ),
                _DetailRow(
                  icon: Icons.memory_rounded,
                  label: 'Device',
                  value: event.deviceId,
                  isDark: isDark,
                ),
                _DetailRow(
                  icon: Icons.category_rounded,
                  label: 'Event Kind',
                  value: event.eventKind,
                  isDark: isDark,
                  mono: true,
                ),
                if (event.rms != null)
                  _DetailRow(
                    icon: Icons.graphic_eq_rounded,
                    label: 'RMS',
                    value: '${event.rms!.toStringAsFixed(0)} ADC',
                    isDark: isDark,
                  ),
                if (event.leakProbability != null)
                  _DetailRow(
                    icon: Icons.water_drop_outlined,
                    label: 'Leak Prob.',
                    value:
                        '${(event.leakProbability! * 100).toStringAsFixed(1)}%',
                    isDark: isDark,
                  ),
                if (event.gasDelta != null)
                  _DetailRow(
                    icon: Icons.air_rounded,
                    label: 'Gas Δ',
                    value: '${event.gasDelta!} ADC',
                    isDark: isDark,
                  ),
                if (event.temperature != null)
                  _DetailRow(
                    icon: Icons.thermostat_rounded,
                    label: 'Temperature',
                    value: '${event.temperature!.toStringAsFixed(1)} °C',
                    isDark: isDark,
                  ),
                if (event.distanceMm != null)
                  _DetailRow(
                    icon: Icons.straighten_rounded,
                    label: 'Distance',
                    value: '${event.distanceMm!} mm',
                    isDark: isDark,
                  ),
                if (event.batteryVoltage != null)
                  _DetailRow(
                    icon: Icons.battery_charging_full_rounded,
                    label: 'Battery',
                    value: '${event.batteryVoltage!.toStringAsFixed(2)} V',
                    isDark: isDark,
                  ),
                if (event.hazardStateLabel != null)
                  _DetailRow(
                    icon: Icons.shield_outlined,
                    label: 'Hazard State',
                    value: event.hazardStateLabel!,
                    isDark: isDark,
                  ),
                _DetailRow(
                  icon: Icons.tag_rounded,
                  label: 'Event ID',
                  value: '${event.id}',
                  isDark: isDark,
                  mono: true,
                ),

                if (event.alert != null && event.alert!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.alertDanger.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.alertDanger.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppColors.alertDanger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.alert!,
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

                if (event.cause != null && event.cause!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.industrialIvory,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Cause: ${event.cause!}',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool mono;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.warmGraphite,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.inter(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.warmGraphite,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? AppTypography.mono(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.carbon,
                    )
                  : AppTypography.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.carbon,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
