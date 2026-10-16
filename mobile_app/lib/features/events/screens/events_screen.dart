import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/event.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_pill.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Events Screen — chronological event/alert history browser
// ──────────────────────────────────────────────────────────────────────────────

enum _EventSeverityFilter { all, danger, caution, normal }

// Provider for events browsing (cross-device, uses selected device or all)
final _eventsScreenProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  final deviceId = ref.watch(selectedDeviceIdProvider) ?? 'SIH-DEV-01';
  final repo = ref.watch(deviceRepositoryProvider);
  return repo.getDeviceEvents(deviceId, limit: 100);
});

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  _EventSeverityFilter _filter = _EventSeverityFilter.all;

  List<Event> _applyFilter(List<Event> events) {
    switch (_filter) {
      case _EventSeverityFilter.all:
        return events;
      case _EventSeverityFilter.danger:
        return events.where((e) => e.alert == 'DANGER').toList();
      case _EventSeverityFilter.caution:
        return events
            .where((e) => e.alert == 'CAUTION' || e.alert == 'WARNING')
            .toList();
      case _EventSeverityFilter.normal:
        return events
            .where((e) => e.alert == null || e.alert == 'NORMAL')
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(_eventsScreenProvider);
    final selectedDeviceId =
        ref.watch(selectedDeviceIdProvider) ?? 'SIH-DEV-01';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EVENT TIMELINE',
              style: AppTypography.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.carbon,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              selectedDeviceId,
              style: AppTypography.mono(
                fontSize: 10,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.warmGraphite,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_eventsScreenProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Severity filter bar ──
          Container(
            color: isDark ? AppColors.darkCanvas : AppColors.industrialIvory,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _EventSeverityFilter.values.map((f) {
                  final isSelected = _filter == f;
                  Color chipColor;
                  switch (f) {
                    case _EventSeverityFilter.danger:
                      chipColor = AppColors.alertDanger;
                    case _EventSeverityFilter.caution:
                      chipColor = AppColors.alertCaution;
                    case _EventSeverityFilter.normal:
                      chipColor = AppColors.alertOk;
                    default:
                      chipColor = AppColors.burntOrange;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SeverityFilterChip(
                      label: _filterLabel(f),
                      selected: isSelected,
                      color: isSelected ? chipColor : null,
                      onTap: () => setState(() => _filter = f),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.warmStone,
          ),

          // ── Event list ──
          Expanded(
            child: eventsAsync.when(
              loading: () => const IndustrialLoadingView(
                message: 'Loading event timeline...',
              ),
              error: (err, _) => IndustrialErrorView(
                title: 'Event Timeline Unavailable',
                message:
                    'Could not retrieve event history. Check backend connectivity.',
                onRetry: () => ref.invalidate(_eventsScreenProvider),
              ),
              data: (events) {
                final filtered = _applyFilter(events);

                if (events.isEmpty) {
                  return IndustrialEmptyView(
                    icon: Icons.timeline_outlined,
                    title: 'No Events Recorded',
                    message:
                        'No diagnostic events have been recorded for $selectedDeviceId yet.\n'
                        'Press the BOOT button on the device to start a session.',
                    actionLabel: 'Refresh',
                    onAction: () => ref.invalidate(_eventsScreenProvider),
                  );
                }

                if (filtered.isEmpty) {
                  return IndustrialEmptyView(
                    icon: Icons.filter_list_off_rounded,
                    title: 'No Matching Events',
                    message: 'No events match the current severity filter.',
                    actionLabel: 'Show All',
                    onAction: () => setState(
                      () => _filter = _EventSeverityFilter.all,
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_eventsScreenProvider),
                  color: AppColors.burntOrange,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return StaggeredEntrance(
                        index: index.clamp(0, 15), // cap stagger at 15
                        child: _EventTile(
                          event: filtered[index],
                          onTap: () => _showEventDetail(
                            context,
                            filtered[index],
                            isDark,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(_EventSeverityFilter f) {
    switch (f) {
      case _EventSeverityFilter.all:
        return 'All Events';
      case _EventSeverityFilter.danger:
        return 'Danger';
      case _EventSeverityFilter.caution:
        return 'Caution';
      case _EventSeverityFilter.normal:
        return 'Normal';
    }
  }

  void _showEventDetail(
    BuildContext context,
    Event event,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventDetailSheet(event: event),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Event Tile — compact row with severity left-border accent
// ──────────────────────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const _EventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color alertColor;
    StatusType statusType;

    switch (event.alert) {
      case 'DANGER':
        alertColor = AppColors.alertDanger;
        statusType = StatusType.danger;
      case 'CAUTION':
      case 'WARNING':
        alertColor = AppColors.alertCaution;
        statusType = StatusType.caution;
      case 'NORMAL':
      case null:
        alertColor = AppColors.alertOk;
        statusType = StatusType.ok;
      default:
        alertColor = AppColors.warmGraphite;
        statusType = StatusType.neutral;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.warmStone,
            width: 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AppColors.carbon.withValues(alpha: 0.025),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Severity left-border bar
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: alertColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Event type icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: alertColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _eventIcon(event),
                        size: 18,
                        color: alertColor,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Event info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.eventName ??
                                      _eventKindLabel(event.eventKind),
                                  style: AppTypography.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.carbon,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (event.alert != null &&
                                  event.alert != 'NORMAL') ...[
                                const SizedBox(width: 8),
                                StatusPill(
                                  label: event.alert!,
                                  type: statusType,
                                  showDot: false,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (event.rms != null)
                                Text(
                                  'RMS ${event.rms!.toStringAsFixed(0)}',
                                  style: AppTypography.mono(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.warmGraphite,
                                  ),
                                ),
                              if (event.rms != null && event.cause != null)
                                Text(
                                  ' · ',
                                  style: AppTypography.inter(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.subtleGray,
                                  ),
                                ),
                              if (event.cause != null)
                                Flexible(
                                  child: Text(
                                    event.cause!,
                                    style: AppTypography.inter(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.warmGraphite,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Timestamp
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(event.serverTimestamp),
                          style: AppTypography.mono(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.subtleGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.subtleGray,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _eventIcon(Event event) {
    if (event.alert == 'DANGER') return Icons.warning_rounded;
    if (event.alert == 'CAUTION') return Icons.warning_amber_rounded;
    if (event.eventKind == 'session_start') return Icons.play_circle_outline_rounded;
    if (event.eventKind == 'session_end') return Icons.stop_circle_outlined;
    if (event.hasAcousticData) return Icons.graphic_eq_rounded;
    if (event.hasGasData) return Icons.air_rounded;
    return Icons.sensors_rounded;
  }

  String _eventKindLabel(String kind) {
    switch (kind) {
      case 'session_start':
        return 'Session Started';
      case 'session_end':
        return 'Session Ended';
      case 'event':
        return 'Telemetry Event';
      case 'summary':
        return 'Session Summary';
      default:
        return kind.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    final now = DateTime.now();
    if (now.difference(local).inDays < 1) {
      return DateFormat('HH:mm:ss').format(local);
    }
    return DateFormat('MMM d, HH:mm').format(local);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Event Detail Bottom Sheet
// ──────────────────────────────────────────────────────────────────────────────

class _EventDetailSheet extends StatelessWidget {
  final Event event;

  const _EventDetailSheet({required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.pureWhite;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.warmStone,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.eventName ?? 'Event Detail',
                        style: AppTypography.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.carbon,
                        ),
                      ),
                    ),
                    if (event.alert != null) ...[
                      StatusPill(
                        label: event.alert!,
                        type: event.alert == 'DANGER'
                            ? StatusType.danger
                            : event.alert == 'CAUTION'
                                ? StatusType.caution
                                : StatusType.ok,
                      ),
                    ],
                  ],
                ),
              ),

              Divider(
                height: 20,
                color: isDark ? AppColors.darkBorder : AppColors.warmStone,
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    children: [
                      _DetailSection(
                        isDark: isDark,
                        title: 'IDENTIFICATION',
                        rows: [
                          ('Event ID', '#${event.id}', true),
                          ('Device', event.deviceId, true),
                          ('Kind', event.eventKind, false),
                          ('Trainee', event.traineeId, false),
                        ],
                      ),
                      _DetailSection(
                        isDark: isDark,
                        title: 'TIMESTAMP',
                        rows: [
                          (
                            'Server UTC',
                            _fmtFull(event.serverTimestamp),
                            true
                          ),
                          if (event.deviceTimestamp != null)
                            (
                              'Device Tick',
                              '${event.deviceTimestamp}',
                              true
                            ),
                          if (event.deviceUptimeMs != null)
                            (
                              'Uptime',
                              '${(event.deviceUptimeMs! / 1000).toStringAsFixed(1)} s',
                              false
                            ),
                        ],
                      ),
                      if (event.hasAcousticData)
                        _DetailSection(
                          isDark: isDark,
                          title: 'ACOUSTIC',
                          rows: [
                            if (event.rms != null)
                              ('RMS', '${event.rms!.toStringAsFixed(2)} ADC', true),
                            if (event.modelLabel != null)
                              ('Model Label', event.modelLabel!, false),
                            if (event.leakProbability != null)
                              (
                                'Leak Prob.',
                                '${(event.leakProbability! * 100).toStringAsFixed(1)}%',
                                true
                              ),
                          ],
                        ),
                      if (event.hasGasData)
                        _DetailSection(
                          isDark: isDark,
                          title: 'GAS SENSOR',
                          rows: [
                            if (event.gasDelta != null)
                              ('Delta', '${event.gasDelta}', true),
                            if (event.gasRatio != null)
                              (
                                'Ratio',
                                event.gasRatio!.toStringAsFixed(3),
                                true
                              ),
                          ],
                        ),
                      if (event.hasMoistureData || event.hasTemperatureData)
                        _DetailSection(
                          isDark: isDark,
                          title: 'ENVIRONMENT',
                          rows: [
                            if (event.wet != null)
                              (
                                'Moisture',
                                event.wet! ? 'WET' : 'DRY',
                                false
                              ),
                            if (event.temperature != null)
                              (
                                'Temperature',
                                '${event.temperature!.toStringAsFixed(1)} °C',
                                true
                              ),
                          ],
                        ),
                      if (event.hasHazardData)
                        _DetailSection(
                          isDark: isDark,
                          title: 'HAZARD FUSION (TinyML)',
                          rows: [
                            if (event.hazardStateLabel != null)
                              (
                                'State',
                                event.hazardStateLabel!,
                                false
                              ),
                            if (event.hazardConf != null)
                              (
                                'Confidence',
                                '${event.hazardConf}/100',
                                true
                              ),
                          ],
                        ),
                      if (event.cause != null || event.alert != null)
                        _DetailSection(
                          isDark: isDark,
                          title: 'ALERT',
                          rows: [
                            if (event.alert != null)
                              ('Severity', event.alert!, false),
                            if (event.cause != null)
                              ('Cause', event.cause!, false),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtFull(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(local);
  }
}

class _DetailSection extends StatelessWidget {
  final bool isDark;
  final String title;
  final List<(String, String, bool isMono)> rows;

  const _DetailSection({
    required this.isDark,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: AppTypography.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextSecondary : AppColors.warmGraphite,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : AppColors.industrialIvory,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.warmStone,
              width: 1,
            ),
          ),
          child: Column(
            children: rows.asMap().entries.map((entry) {
              final isLast = entry.key == rows.length - 1;
              final (label, value, isMono) = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Text(
                          label,
                          style: AppTypography.inter(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.warmGraphite,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          value,
                          style: isMono
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
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Severity Filter Chip
// ──────────────────────────────────────────────────────────────────────────────

class _SeverityFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _SeverityFilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = color ?? AppColors.burntOrange;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? activeColor
              : (isDark ? AppColors.darkSurfaceElevated : AppColors.pureWhite),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? activeColor
                : (isDark ? AppColors.darkBorder : AppColors.warmStone),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppColors.pureWhite
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.warmGraphite),
          ),
        ),
      ),
    );
  }
}
