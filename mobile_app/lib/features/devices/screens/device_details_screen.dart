import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/backgrounds/animated_screen_background.dart';
import '../../../shared/backgrounds/diagnostic_radar_sweep.dart';
import '../../../shared/models/device.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/session.dart';
import '../../../shared/motion/pulsing_beacon.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/industrial_button.dart';
import '../../../shared/widgets/industrial_card.dart';
import '../../../shared/widgets/metric_readout.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_pill.dart';

final singleDeviceStatusProvider =
    FutureProvider.family<DeviceStatus, String>((ref, deviceId) async {
      final repo = ref.watch(deviceRepositoryProvider);
      return await repo.getDeviceStatus(deviceId);
    });

final singleDeviceDetailsProvider = FutureProvider.family<Device, String>((
  ref,
  deviceId,
) async {
  final repo = ref.watch(deviceRepositoryProvider);
  return await repo.getDevice(deviceId);
});

class DeviceDetailsScreen extends ConsumerStatefulWidget {
  final String deviceId;

  const DeviceDetailsScreen({super.key, required this.deviceId});

  @override
  ConsumerState<DeviceDetailsScreen> createState() =>
      _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends ConsumerState<DeviceDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _eventFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(singleDeviceStatusProvider(widget.deviceId));
    ref.invalidate(singleDeviceDetailsProvider(widget.deviceId));
    ref.invalidate(deviceEventsProvider(widget.deviceId));
    ref.invalidate(deviceSummariesProvider(widget.deviceId));
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(singleDeviceStatusProvider(widget.deviceId));
    final deviceAsync = ref.watch(
      singleDeviceDetailsProvider(widget.deviceId),
    );
    final eventsAsync = ref.watch(deviceEventsProvider(widget.deviceId));
    final summariesAsync = ref.watch(deviceSummariesProvider(widget.deviceId));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text('NODE: ${widget.deviceId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Sync Node Telemetry',
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.burntOrange,
          unselectedLabelColor: isDark
              ? AppColors.darkTextSecondary
              : AppColors.warmGraphite,
          indicatorColor: AppColors.burntOrange,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'SENSORS & LIVE'),
            Tab(text: 'EVENT TIMELINE'),
            Tab(text: 'SUMMARIES'),
            Tab(text: 'DIAGNOSTICS'),
            Tab(text: 'RAW TELEMETRY'),
          ],
        ),
      ),
      body: AnimatedScreenBackground(
        theme: ScreenBackgroundTheme.circuitTrace,
        intensity: 0.75,
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Sensors & Live Overview
            _buildSensorsAndLiveTab(
              context,
              statusAsync,
              deviceAsync,
              eventsAsync,
              isDark,
            ),

            // Tab 2: Chronological Event Timeline
            _buildEventTimelineTab(context, eventsAsync, isDark),

            // Tab 3: Session Summaries
            _buildSummariesTab(context, summariesAsync, isDark),

            // Tab 4: Hardware & Bus Diagnostics
            _buildDiagnosticsTab(context, statusAsync, deviceAsync, isDark),

            // Tab 5: Raw Telemetry JSON Inspector
            _buildRawTelemetryTab(
              context,
              eventsAsync,
              summariesAsync,
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: SENSORS & LIVE OVERVIEW
  // =========================================================================
  Widget _buildSensorsAndLiveTab(
    BuildContext context,
    AsyncValue<DeviceStatus> statusAsync,
    AsyncValue<Device> deviceAsync,
    AsyncValue<List<Event>> eventsAsync,
    bool isDark,
  ) {
    return statusAsync.when(
      data: (status) {
        final device = deviceAsync.valueOrNull;
        final isOnline = status.isOnline;
        final events = eventsAsync.valueOrNull ?? [];
        final latestEvent = events.isNotEmpty ? events.first : null;
        final rms = latestEvent?.rms;
        final gasDelta = latestEvent?.gasDelta;
        final gasRatio = latestEvent?.gasRatio;
        final wet = latestEvent?.wet;
        final temp = latestEvent?.temperature;
        final uv = latestEvent?.uvDelta;
        final leakProb = latestEvent?.leakProbability;

        // Use Device model connectivity methods if available
        final connectivityStatus = device?.connectivityStatus ?? (isOnline ? 'online' : 'offline');
        final stalenessText = device?.stalenessText ?? (status.lastSeenAt != null
            ? DateFormat('yyyy-MM-dd • HH:mm:ss').format(status.lastSeenAt!.toLocal())
            : 'Never seen');

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── 1. Live Hardware Node Status Card ──
            StaggeredEntrance(
              index: 0,
              child: IndustrialCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            DiagnosticRadarSweep(
                              size: 52,
                              isScanning: isOnline,
                            ),
                            Icon(
                              isOnline
                                  ? Icons.sensors_rounded
                                  : Icons.sensors_off_rounded,
                              color: isOnline
                                  ? AppColors.burntOrange
                                  : AppColors.warmGraphite,
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    status.deviceId,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isOnline) ...[
                                    const PulsingBeacon(
                                      size: 8,
                                      color: AppColors.alertOk,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  StatusPill(
                                    label: connectivityStatus.toUpperCase(),
                                    type: connectivityStatus == 'online'
                                        ? StatusType.online
                                        : (connectivityStatus == 'offline'
                                            ? StatusType.offline
                                            : StatusType.neutral),
                                    showDot: connectivityStatus != 'online',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                status.firmwareVersion != null
                                    ? 'Firmware: v${status.firmwareVersion}'
                                    : 'Firmware: v1.1.0 (Rig Standard)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warmGraphite,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LAST CONTACT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.warmGraphite,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stalenessText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: device?.isStale == true
                                    ? AppColors.alertCaution
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        IndustrialButton(
                          label: 'Set as Active Probe',
                          height: 34,
                          variant: IndustrialButtonVariant.secondary,
                          onPressed: () {
                            ref
                                .read(selectedDeviceIdProvider.notifier)
                                .state = widget.deviceId;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Node ${widget.deviceId} selected as active workstation probe.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Staleness Warning Banner ──
            if (device?.isStale == true)
              StaggeredEntrance(
                index: 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFFFF3E0) // Light orange warning
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.alertCaution,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.alertCaution,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Device data is stale. Last contact was ${device?.stalenessText ?? "unknown"}.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkBurntOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // ── 3. Real Sensor Measurements Readouts ──
            StaggeredEntrance(
              index: 2,
              child: IndustrialCard(
                title: 'LIVE SENSOR READINGS',
                subtitle: 'Actual ADC & Transducer Values Transmitted by Node',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MetricReadout(
                            label: 'ACOUSTIC RMS',
                            value: rms != null ? rms.toStringAsFixed(1) : '--',
                            unit: 'ADC',
                            icon: Icons.graphic_eq_rounded,
                            accentColor: AppColors.burntOrange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MetricReadout(
                            label: 'COMBUSTIBLE GAS',
                            value: gasDelta != null
                                ? (gasDelta >= 0 ? '+$gasDelta' : '$gasDelta')
                                : '--',
                            unit: 'Δ ADC',
                            icon: Icons.air_rounded,
                            accentColor: AppColors.darkBurntOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: MetricReadout(
                            label: 'GAS RS/R0 RATIO',
                            value: gasRatio != null
                                ? gasRatio.toStringAsFixed(2)
                                : '--',
                            unit: 'ratio',
                            icon: Icons.tune_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MetricReadout(
                            label: 'MOISTURE PROBE',
                            value: wet != null ? (wet ? 'WET' : 'DRY') : '--',
                            unit: 'conduction',
                            icon: Icons.water_drop_outlined,
                            accentColor:
                                wet == true ? AppColors.alertDanger : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: MetricReadout(
                            label: 'PYROMETER TEMP',
                            value: temp != null
                                ? '${temp.toStringAsFixed(1)}°C'
                                : 'DISABLED',
                            unit: temp != null ? '' : 'rig',
                            icon: Icons.thermostat_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MetricReadout(
                            label: 'UV RADIOMETER',
                            value: uv != null ? '+$uv' : 'DISABLED',
                            unit: uv != null ? 'Δ ADC' : 'rig',
                            icon: Icons.wb_sunny_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.industrialIvory,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.warmStone,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppColors.warmGraphite,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Gas is baseline-relative ADC delta counts (not calibrated ppm). '
                              'Pyrometer/UV channels are disabled in standard acoustic rig config.',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                                color: AppColors.warmGraphite,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 4. Detection & Machine Learning Analysis ──
            StaggeredEntrance(
              index: 3,
              child: IndustrialCard(
                title: 'DETECTION & MODEL VERDICT',
                subtitle: 'Acoustic Pipeline & Multi-Hazard Sensor Arbitration',
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Leak Probability',
                      leakProb != null
                          ? '${(leakProb * 100).toStringAsFixed(0)}% (score: ${leakProb.toStringAsFixed(2)})'
                          : 'Awaiting Pipeline Analysis',
                      valueColor: (leakProb ?? 0.0) >= 0.65
                          ? AppColors.alertDanger
                          : AppColors.alertOk,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'TinyML Top Label',
                      latestEvent?.modelLabel ?? 'No Frame Processed',
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'Root Cause Verdict',
                      latestEvent?.cause ?? 'CAUSE_STARTUP',
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'Arbitration Alert',
                      latestEvent?.alert ?? 'ALERT_OK',
                      valueColor: latestEvent?.alert == 'DANGER'
                          ? AppColors.alertDanger
                          : (latestEvent?.alert == 'CAUTION'
                              ? AppColors.alertCaution
                              : AppColors.alertOk),
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'Classifier Thresholds',
                      'LEAK >= 0.65 • NOISE >= 0.60 • NORMAL >= 0.60',
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'Temporal Debounce',
                      '2 Consecutive Windows Assert • 4 Clear',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 4 & 5. Motion/IMU & EMG Sensor Availability Disclosure ──
            StaggeredEntrance(
              index: 3,
              child: IndustrialCard(
                title: 'AUXILIARY HARDWARE SUPPORT',
                subtitle: 'Verification of Unmounted Sensor Subsystems',
                child: Column(
                  children: [
                    _buildSensorStatusRow(
                      icon: Icons.screen_rotation_rounded,
                      title: 'Motion / IMU (6-Axis Gyro & Accel)',
                      statusText: 'UNSUPPORTED / HARDWARE NOT MOUNTED',
                      description:
                          'The NAADYANTRA inspection rig utilizes an acoustic contact-piezo transducer on pipe valves. MPU-6050 / IMU is not present on this hardware revision.',
                      isSupported: false,
                    ),
                    const Divider(),
                    _buildSensorStatusRow(
                      icon: Icons.electric_bolt_rounded,
                      title: 'EMG / Biopotential Signal Probe',
                      statusText: 'UNSUPPORTED / NOT APPLICABLE',
                      description:
                          'Electromyography biopotential sensing is not part of this pipeline NDT acoustic rig.',
                      isSupported: false,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const IndustrialLoadingView(
        message: 'Establishing telemetry connection to probe...',
      ),
      error: (err, _) => IndustrialErrorView(
        title: 'Probe Unreachable',
        message: err.toString(),
        onRetry: _refreshAll,
      ),
    );
  }

  // =========================================================================
  // TAB 2: EVENT TIMELINE & FILTERING
  // =========================================================================
  Widget _buildEventTimelineTab(
    BuildContext context,
    AsyncValue<List<Event>> eventsAsync,
    bool isDark,
  ) {
    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return IndustrialEmptyView(
            icon: Icons.history_rounded,
            title: 'No Telemetry Events Logged',
            message:
                'Trigger an active inspection session or simulate telemetry to populate records.',
            actionLabel: 'Refresh Timeline',
            onAction: _refreshAll,
          );
        }

        var filtered = events;
        if (_eventFilter == 'LEAKS') {
          filtered = events
              .where(
                (e) =>
                    (e.cause?.toUpperCase().contains('LEAK') ?? false) ||
                    (e.leakProbability ?? 0) >= 0.65,
              )
              .toList();
        } else if (_eventFilter == 'GAS') {
          filtered = events
              .where(
                (e) =>
                    (e.cause?.toUpperCase().contains('GAS') ?? false) ||
                    (e.gasDelta ?? 0) >= 150,
              )
              .toList();
        } else if (_eventFilter == 'STATE') {
          filtered = events.where((e) => e.eventName == 'state').toList();
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All Events (${events.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'LEAKS',
                    'Leaks (${events.where((e) => (e.cause?.contains('LEAK') ?? false) || (e.leakProbability ?? 0) >= 0.65).length})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'GAS',
                    'Gas Alarms (${events.where((e) => (e.cause?.contains('GAS') ?? false) || (e.gasDelta ?? 0) >= 150).length})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'STATE',
                    'State Changes (${events.where((e) => e.eventName == 'state').length})',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No events match filter "$_eventFilter"',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.warmGraphite,
                    ),
                  ),
                ),
              )
            else
              ...filtered.map((e) => _buildEventItemCard(context, e, isDark)),

            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const IndustrialLoadingView(
        message: 'Loading chronological event records...',
      ),
      error: (err, _) => IndustrialErrorView(
        title: 'Event Timeline Unavailable',
        message: err.toString(),
        onRetry: _refreshAll,
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _eventFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isSelected
              ? AppColors.pureWhite
              : (isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.warmGraphite),
        ),
      ),
      selectedColor: AppColors.burntOrange,
      backgroundColor: isDark
          ? AppColors.darkSurfaceElevated
          : AppColors.warmStone.withValues(alpha: 0.35),
      checkmarkColor: AppColors.pureWhite,
      side: BorderSide(
        color: isSelected
            ? AppColors.burntOrange
            : (isDark ? AppColors.darkBorder : AppColors.warmStone),
      ),
      onSelected: (_) => setState(() => _eventFilter = value),
    );
  }

  Widget _buildEventItemCard(BuildContext context, Event event, bool isDark) {
    final isDanger = event.alert == 'DANGER';
    final isCaution = event.alert == 'CAUTION';
    final alertColor = isDanger
        ? AppColors.alertDanger
        : (isCaution ? AppColors.alertCaution : AppColors.alertOk);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDanger
              ? AppColors.alertDanger.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.warmStone),
          width: isDanger ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isDanger
                      ? Icons.warning_rounded
                      : (isCaution
                          ? Icons.info_outline_rounded
                          : Icons.check_circle_outline_rounded),
                  color: alertColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${event.eventName ?? "EVENT"} • ${event.cause ?? "CAUSE_NONE"}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill(
                label: event.alert ?? 'OK',
                type: isDanger
                    ? StatusType.danger
                    : (isCaution ? StatusType.caution : StatusType.ok),
                showDot: false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RMS: ${event.rms != null ? event.rms!.toStringAsFixed(1) : "--"} ADC',
                style: const TextStyle(
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'Gas Δ: ${event.gasDelta != null ? "+${event.gasDelta}" : "--"}',
                style: const TextStyle(
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'Leak: ${event.leakProbability != null ? "${(event.leakProbability! * 100).toStringAsFixed(0)}%" : "--"}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: (event.leakProbability ?? 0) >= 0.65
                      ? AppColors.alertDanger
                      : AppColors.alertOk,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session: #${event.sessionId} • Trainee: ${event.traineeId}',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.warmGraphite,
                ),
              ),
              Text(
                DateFormat('HH:mm:ss').format(event.serverTimestamp.toLocal()),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.warmGraphite,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: SESSION SUMMARIES
  // =========================================================================
  Widget _buildSummariesTab(
    BuildContext context,
    AsyncValue<List<SessionSummary>> summariesAsync,
    bool isDark,
  ) {
    return summariesAsync.when(
      data: (summaries) {
        if (summaries.isEmpty) {
          return IndustrialEmptyView(
            icon: Icons.assessment_outlined,
            title: 'No Session Summaries Recorded',
            message:
                'Session summaries are transmitted by ESP32 firmware upon session completion (stopSession).',
            actionLabel: 'Check for Summaries',
            onAction: _refreshAll,
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: summaries
              .map((summary) => _buildSummaryCard(context, summary, isDark))
              .toList(),
        );
      },
      loading: () => const IndustrialLoadingView(
        message: 'Loading device session summary archives...',
      ),
      error: (err, _) => IndustrialErrorView(
        title: 'Summaries Unavailable',
        message: err.toString(),
        onRetry: _refreshAll,
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    SessionSummary summary,
    bool isDark,
  ) {
    final maxLeakPct = summary.maxLeakProbability != null
        ? (summary.maxLeakProbability! * 100).toStringAsFixed(0)
        : '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: IndustrialCard(
        title: 'SESSION #${summary.deviceSessionId} SUMMARY',
        subtitle:
            'Trainee: ${summary.traineeId} • Node: ${summary.deviceId}',
        trailing: StatusPill(
          label: 'DURATION: ${summary.durationSeconds ?? 0}s',
          type: StatusType.completed,
          showDot: false,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: MetricReadout(
                    label: 'WINDOWS SAMPLED',
                    value: '${summary.windows ?? 0}',
                    unit: 'frames',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricReadout(
                    label: 'MAX LEAK PROB',
                    value: '$maxLeakPct%',
                    unit: 'score',
                    accentColor: (summary.maxLeakProbability ?? 0) >= 0.65
                        ? AppColors.alertDanger
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Acoustic Leak Events',
              '${summary.leakEvents ?? 0}',
            ),
            const Divider(),
            _buildDetailRow(
              'Combustible Gas Events',
              '${summary.gasEvents ?? 0}',
            ),
            const Divider(),
            _buildDetailRow('Moisture Wet Events', '${summary.wetEvents ?? 0}'),
            const Divider(),
            _buildDetailRow(
              'Ambient Noise Windows',
              '${summary.noiseWindows ?? 0}',
            ),
            const Divider(),
            _buildDetailRow(
              'Firmware Version',
              summary.firmwareVersion ?? 'v1.1.0',
            ),
            const Divider(),
            _buildDetailRow(
              'Server Recorded Timestamp',
              DateFormat('yyyy-MM-dd HH:mm:ss').format(
                summary.serverTimestamp.toLocal(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 4: HARDWARE & DIAGNOSTICS
  // =========================================================================
  Widget _buildDiagnosticsTab(
    BuildContext context,
    AsyncValue<DeviceStatus> statusAsync,
    AsyncValue<Device> deviceAsync,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Active Ingestion Error Banner (if any)
        statusAsync.when(
          data: (status) {
            if (status.lastError == null) {
              return Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.alertOk.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.alertOk.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.alertOk,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ingestion Pipeline Healthy — 0 Packet Drop Errors',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.alertOk,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.alertDanger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.alertDanger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.alertDanger,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Last Ingestion Error: ${status.lastError}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.alertDanger,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        // Architecture Card
        IndustrialCard(
          title: 'HARDWARE & BUS SPECIFICATIONS',
          subtitle: 'ESP32 Firmware Rig Configuration',
          child: Column(
            children: [
              _buildDetailRow(
                'MCU Architecture',
                'ESP32-S3 Dual-Core LX7 @ 240 MHz (Xtensa)',
              ),
              const Divider(),
              _buildDetailRow(
                'Acoustic Transducer',
                'Piezoelectric Contact Pickup • 1.65V Virtual Ground',
              ),
              const Divider(),
              _buildDetailRow(
                'Sampling Frequency',
                '4000 Hz / Edge Impulse Target (Timer ISR)',
              ),
              const Divider(),
              _buildDetailRow(
                'Windowing & Overlap',
                '1000ms Analysis Window • 500ms Hop (50% Overlap)',
              ),
              const Divider(),
              _buildDetailRow(
                'Digital Filtering',
                '1st-Order IIR DC-Block Filter (R = 0.995)',
              ),
              const Divider(),
              _buildDetailRow(
                'ADC Resolution',
                '12-bit Hardware ADC1 (0 - 4095 Counts, 11dB Atten)',
              ),
              const Divider(),
              _buildDetailRow(
                'Ring Buffer Depth',
                'Dual-Core Ring Buffer with Atomic Head Pointer',
              ),
              const Divider(),
              _buildDetailRow(
                'FreeRTOS Ring Queue',
                '40 Frames (Uploader Drop-Oldest on Saturated Bus)',
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Cloud & Protocol Card
        IndustrialCard(
          title: 'TELEMETRY DISPATCH PROTOCOL',
          subtitle: 'REST Gateway Contract Compliance',
          child: Column(
            children: [
              _buildDetailRow(
                'Target Endpoint',
                'POST /api/log?trainee={id}&session={id}&kind={kind}',
              ),
              const Divider(),
              _buildDetailRow(
                'Security Auth',
                'Header: X-Device-Key (Bcrypt Hashed in PostgreSQL/SQLite)',
              ),
              const Divider(),
              _buildDetailRow(
                'Deduplication',
                'SHA-256 Idempotency Key (Safe for Resend Retries)',
              ),
              const Divider(),
              _buildDetailRow(
                'Session Linkage',
                'Auto-Session Record Creation & Trainee Registry Linking',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // =========================================================================
  // TAB 5: RAW TELEMETRY JSON INSPECTOR
  // =========================================================================
  Widget _buildRawTelemetryTab(
    BuildContext context,
    AsyncValue<List<Event>> eventsAsync,
    AsyncValue<List<SessionSummary>> summariesAsync,
    bool isDark,
  ) {
    final events = eventsAsync.valueOrNull ?? [];
    final summaries = summariesAsync.valueOrNull ?? [];

    if (events.isEmpty && summaries.isEmpty) {
      return IndustrialEmptyView(
        icon: Icons.code_rounded,
        title: 'No Raw Telemetry Packets Recorded',
        message:
            'Original JSON payloads from physical ESP32 broadcasts will appear here for inspection.',
        actionLabel: 'Refresh Packets',
        onAction: _refreshAll,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'LATEST EVENT PAYLOADS (${events.length} ARCHIVED)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.warmGraphite,
            ),
          ),
        ),
        ...events.take(15).map((e) => _buildJsonExpandableCard(
              context,
              title:
                  'EVENT #${e.id} [${e.eventName ?? "state"}] — ${DateFormat("HH:mm:ss").format(e.serverTimestamp.toLocal())}',
              badge: e.alert ?? 'OK',
              payload: e.rawPayload.isNotEmpty
                  ? e.rawPayload
                  : {
                      't': e.deviceTimestamp,
                      'up': e.deviceUptimeMs,
                      'ev': e.eventName,
                      'alert': e.alert,
                      'cause': e.cause,
                      'lbl': e.modelLabel,
                      'pl': e.leakProbability,
                      'rms': e.rms,
                      'gas': e.gasDelta,
                      'gr': e.gasRatio,
                      'tc': e.temperature,
                      'uv': e.uvDelta,
                      'wet': e.wet == true ? 1 : 0,
                    },
              isDark: isDark,
            )),
        if (summaries.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'SESSION SUMMARY PAYLOADS (${summaries.length} ARCHIVED)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.warmGraphite,
              ),
            ),
          ),
          ...summaries.map((s) => _buildJsonExpandableCard(
                context,
                title:
                    'SUMMARY #${s.id} [SESS ${s.deviceSessionId}] — ${DateFormat("yyyy-MM-dd HH:mm").format(s.serverTimestamp.toLocal())}',
                badge: 'SUMMARY',
                payload: s.rawPayload.isNotEmpty
                    ? s.rawPayload
                    : {
                        'session_id': s.deviceSessionId,
                        'trainee': s.traineeId,
                        'dur_s': s.durationSeconds,
                        'windows': s.windows,
                        'leak_events': s.leakEvents,
                        'gas_events': s.gasEvents,
                        'wet_events': s.wetEvents,
                        'max_leak_p': s.maxLeakProbability,
                        'device': s.deviceId,
                        'fw': s.firmwareVersion,
                      },
                isDark: isDark,
              )),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildJsonExpandableCard(
    BuildContext context, {
    required String title,
    required String badge,
    required Map<String, dynamic> payload,
    required bool isDark,
  }) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(payload);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.warmStone,
        ),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusPill(
              label: badge,
              type: badge == 'DANGER'
                  ? StatusType.danger
                  : (badge == 'CAUTION'
                      ? StatusType.caution
                      : (badge == 'SUMMARY'
                          ? StatusType.completed
                          : StatusType.ok)),
              showDot: false,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              tooltip: 'Copy JSON',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: prettyJson));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Raw telemetry JSON copied to clipboard'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.carbon : AppColors.industrialIvory,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.warmStone,
              ),
            ),
            child: SelectableText(
              prettyJson,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
                color: isDark ? AppColors.pureWhite : AppColors.carbon,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================
  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.warmGraphite,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: valueColor ??
                    (isDark ? AppColors.darkTextPrimary : AppColors.carbon),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorStatusRow({
    required IconData icon,
    required String title,
    required String statusText,
    required String description,
    required bool isSupported,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warmStone.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.warmGraphite),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    StatusPill(
                      label: statusText,
                      type: StatusType.neutral,
                      showDot: false,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.warmGraphite,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
