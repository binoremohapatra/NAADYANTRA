import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion_tokens.dart';
import '../../../shared/models/session.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/common.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/industrial_card.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/widgets/metric_readout.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/motion/pulsing_beacon.dart';
import '../../../shared/backgrounds/naadyantra_animated_background.dart';

final sessionDetailsProvider = FutureProvider.family<Session, int>((
  ref,
  sessionId,
) async {
  final repo = ref.watch(sessionRepositoryProvider);
  return await repo.getSession(sessionId);
});

final sessionSummaryProvider = FutureProvider.family<SessionSummary, int>((
  ref,
  sessionId,
) async {
  final repo = ref.watch(sessionRepositoryProvider);
  return await repo.getSessionSummary(sessionId);
});

final sessionEventsProvider =
    FutureProvider.family<PaginatedResponse<Event>, String>((
      ref,
      params,
    ) async {
      final parts = params.split(',');
      final sessionId = int.parse(parts[0]);
      final page = parts.length > 1 ? int.parse(parts[1]) : 1;
      final pageSize = parts.length > 2 ? int.parse(parts[2]) : 50;
      final repo = ref.watch(sessionRepositoryProvider);
      return await repo.getSessionEvents(
        sessionId,
        page: page,
        pageSize: pageSize,
      );
    });

class SessionDetailScreen extends ConsumerStatefulWidget {
  final int sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  bool _isExporting = false;

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    try {
      final repo = ref.read(sessionRepositoryProvider);
      final events = await repo.getSessionEvents(
        widget.sessionId,
        pageSize: 200,
      );

      final csvBuffer = StringBuffer();
      csvBuffer.writeln(
        'id,session_id,device_id,timestamp,alert,cause,rms,gas_delta',
      );
      for (final e in events.items) {
        csvBuffer.writeln(
          '${e.id},${e.sessionId},${e.deviceId},${e.serverTimestamp.toIso8601String()},${e.alert ?? ""},${e.cause ?? ""},${e.rms ?? 0},${e.gasDelta ?? 0}',
        );
      }
      final csvString = csvBuffer.toString();

      final dir = await getApplicationDocumentsDirectory();
      final filePath = path.join(
        dir.path,
        'session_${widget.sessionId}_telemetry.csv',
      );
      final file = File(filePath);
      await file.writeAsString(csvString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported telemetry archive to:\n$filePath'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV telemetry: $e'),
            backgroundColor: AppColors.alertDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionDetailsProvider(widget.sessionId));
    final summaryAsync = ref.watch(sessionSummaryProvider(widget.sessionId));
    final eventsAsync = ref.watch(
      sessionEventsProvider('${widget.sessionId},1,50'),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('SESSION #${widget.sessionId}'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: 'Export CSV Audit',
            onPressed: _isExporting ? null : _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Sync Diagnostics',
            onPressed: () {
              ref.invalidate(sessionDetailsProvider(widget.sessionId));
              ref.invalidate(sessionSummaryProvider(widget.sessionId));
              ref.invalidate(sessionEventsProvider('${widget.sessionId},1,50'));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: sessionAsync.when(
        data: (session) =>
            _buildContent(context, session, summaryAsync, eventsAsync),
        loading: () => const IndustrialLoadingView(
          message: 'Decoding Session Telemetry & Events...',
        ),
        error: (error, _) => IndustrialErrorView(
          title: 'Diagnostic Retrieval Error',
          message: error.toString(),
          onRetry: () {
            ref.invalidate(sessionDetailsProvider(widget.sessionId));
            ref.invalidate(sessionSummaryProvider(widget.sessionId));
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Session session,
    AsyncValue<SessionSummary> summaryAsync,
    AsyncValue<PaginatedResponse<Event>> eventsAsync,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NaadyantraAnimatedBackground(
      kind: NaadyantraBackgroundKind.sessionDetails,
      lightScrimOpacity: 0.88,
      darkScrimOpacity: 0.70,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Session Header Card
          StaggeredEntrance(
            index: 0,
            child: _buildSessionHeaderCard(context, session, isDark),
          ),
          const SizedBox(height: 12),

          // Diagnostic Summary & Probability
          StaggeredEntrance(
            index: 1,
            child: _buildSummarySection(context, summaryAsync),
          ),
          const SizedBox(height: 12),

          // Acoustic Spectrogram Visualizer
          summaryAsync.when(
            data: (summary) => StaggeredEntrance(
              index: 2,
              child: _buildAcousticSpectrumCard(context, summary, isDark),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          // Acoustic Events Timeline
          StaggeredEntrance(
            index: 3,
            child: _buildEventsSection(context, eventsAsync),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSessionHeaderCard(
    BuildContext context,
    Session session,
    bool isDark,
  ) {
    return IndustrialCard(
      title: 'Session Profile',
      subtitle: 'Audit & Telemetry Signature Verification',
      trailing: StatusPill(
        label: session.isActive ? 'IN PROGRESS' : 'FINALIZED',
        type: session.isActive ? StatusType.active : StatusType.completed,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildHeaderPill(
                  icon: Icons.memory_rounded,
                  label: 'Probe Node',
                  value: session.deviceId,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeaderPill(
                  icon: Icons.person_outline_rounded,
                  label: 'Trainee Operator',
                  value: session.traineeId,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? AppColors.darkBorder : AppColors.warmStone),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Start Timestamp',
            DateFormat('yyyy-MM-dd HH:mm:ss').format(session.startedAt),
          ),
          if (session.endedAt != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow(
              'End Timestamp',
              DateFormat('yyyy-MM-dd HH:mm:ss').format(session.endedAt!),
            ),
          ],
          const SizedBox(height: 6),
          _buildInfoRow(
            'Execution Duration',
            _formatDuration(session.duration?.inSeconds),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPill({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.industrialIvory,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.warmStone,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.warmGraphite),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.warmGraphite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    AsyncValue<SessionSummary> summaryAsync,
  ) {
    return summaryAsync.when(
      data: (summary) {
        final maxLeak = summary.maxLeakProbability ?? 0.0;
        final leakEventsCount = summary.leakEvents ?? 0;
        final hasLeak = leakEventsCount > 0 || maxLeak > 0.4;
        final isReduced = MotionTokens.isReducedMotion(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'DIAGNOSTIC SUMMARY & EVENT COUNTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.warmGraphite,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: MetricReadout(
                    label: 'Leak Events',
                    value: '$leakEventsCount',
                    icon: Icons.warning_rounded,
                    accentColor: hasLeak
                        ? AppColors.alertDanger
                        : AppColors.alertOk,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricReadout(
                    label: 'Gas Bursts',
                    value: '${summary.gasEvents ?? 0}',
                    icon: Icons.cloud_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricReadout(
                    label: 'Moisture',
                    value: '${summary.wetEvents ?? 0}',
                    icon: Icons.water_drop_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: MetricReadout(
                    label: 'Windows',
                    value: '${summary.windows ?? 0}',
                    unit: 'fft frames',
                    icon: Icons.grain_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricReadout(
                    label: 'Noise Windows',
                    value: '${summary.noiseWindows ?? 0}',
                    unit: 'filtered',
                    icon: Icons.graphic_eq_rounded,
                  ),
                ),
              ],
            ),
            if (summary.maxLeakProbability != null) ...[
              const SizedBox(height: 8),
              IndustrialCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PEAK LEAK PROBABILITY CONFIDENCE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.warmGraphite,
                          ),
                        ),
                        Text(
                          '${(maxLeak * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: hasLeak
                                ? AppColors.alertDanger
                                : AppColors.alertOk,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: isReduced
                          ? LinearProgressIndicator(
                              value: maxLeak.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: AppColors.warmStone.withValues(
                                alpha: 0.5,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                hasLeak
                                    ? AppColors.alertDanger
                                    : AppColors.alertOk,
                              ),
                            )
                          : TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0.0,
                                end: maxLeak.clamp(0.0, 1.0),
                              ),
                              duration: MotionTokens.durationSlow,
                              curve: MotionTokens.curveDecelerate,
                              builder: (context, val, child) {
                                return LinearProgressIndicator(
                                  value: val,
                                  minHeight: 8,
                                  backgroundColor: AppColors.warmStone
                                      .withValues(alpha: 0.5),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    hasLeak
                                        ? AppColors.alertDanger
                                        : AppColors.alertOk,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const IndustrialCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildAcousticSpectrumCard(
    BuildContext context,
    SessionSummary summary,
    bool isDark,
  ) {
    final maxLeak = summary.maxLeakProbability ?? 0.0;
    final hasLeak = (summary.leakEvents ?? 0) > 0 || maxLeak >= 0.65;
    final leakPct = (maxLeak * 100).toStringAsFixed(1);

    return IndustrialCard(
      title: 'Acoustic Diagnostic Profile',
      subtitle: 'On-Node Inference & Contact-Piezo Analysis',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: hasLeak
              ? AppColors.alertDanger.withValues(alpha: 0.1)
              : AppColors.alertOk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          hasLeak ? 'LEAK SIGNATURE ASSERTED' : 'NOMINAL BASELINE',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: hasLeak ? AppColors.alertDanger : AppColors.alertOk,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetricReadout(
                  label: 'Peak Leak Probability',
                  value: '$leakPct%',
                  icon: Icons.psychology_alt_rounded,
                  accentColor: hasLeak
                      ? AppColors.alertDanger
                      : AppColors.alertOk,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricReadout(
                  label: 'Acoustic Windows',
                  value: '${summary.windows ?? 0}',
                  unit: 'frames',
                  icon: Icons.grain_rounded,
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
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.warmStone,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.warmGraphite,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasLeak
                        ? 'Edge Impulse TinyML model asserted leak threshold (≥0.65) during this run with $leakPct% confidence.'
                        : 'Acoustic contacts remained within nominal baseline. Ambient noise filtered: ${summary.noiseWindows ?? 0} windows.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.warmGraphite,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hardware Rig Ground Truth: ESP32 contact-piezo samples at 4000 Hz target with 1024-sample windows (50% hop). Discrete 48 kHz FFT streaming is not transmitted on this single-channel rig.',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.warmGraphite,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsSection(
    BuildContext context,
    AsyncValue<PaginatedResponse<Event>> eventsAsync,
  ) {
    return IndustrialCard(
      title: 'Acoustic Event Timeline',
      subtitle: 'Synchronized Sensor Triggers & Spectrogram Flags',
      child: eventsAsync.when(
        data: (paginatedResponse) {
          if (paginatedResponse.items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 36,
                      color: AppColors.alertOk,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No Anomalies Recorded in this Run',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'All telemetry frames remained within nominal safety thresholds.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warmGraphite,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginatedResponse.items.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final event = paginatedResponse.items[index];
              return _buildEventTile(context, event);
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (error, _) => Text(
          'Failed to load timeline: $error',
          style: const TextStyle(color: AppColors.alertDanger, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildEventTile(BuildContext context, Event event) {
    final alertColor = _getAlertColor(event.alert);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alertUpper = event.alert?.toUpperCase() ?? '';
    final isCritical = alertUpper == 'DANGER' || alertUpper == 'CRITICAL';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: alertColor.withValues(alpha: 0.3)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isCritical) PulsingBeacon(size: 8, color: alertColor),
                Icon(_getAlertIcon(event.alert), color: alertColor, size: 18),
              ],
            ),
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
                      (event.cause ?? 'EVENT').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm:ss').format(event.serverTimestamp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.warmGraphite,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildChip(
                      'RMS: ${event.rms?.toStringAsFixed(1) ?? "0.0"}',
                      isDark,
                    ),
                    _buildChip('Gas: ${event.gasDelta ?? 0}', isDark),
                    _buildChip(
                      'Alert: ${event.alert ?? "NORMAL"}',
                      isDark,
                      color: alertColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool isDark, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color != null
            ? color.withValues(alpha: 0.1)
            : (isDark
                  ? AppColors.darkSurfaceElevated
                  : AppColors.industrialIvory),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color != null
              ? color.withValues(alpha: 0.3)
              : (isDark ? AppColors.darkBorder : AppColors.warmStone),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color:
              color ??
              (isDark ? AppColors.darkTextSecondary : AppColors.warmGraphite),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.warmGraphite),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '00:00';
    final mins = seconds ~/ 60;
    final remSecs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${remSecs.toString().padLeft(2, '0')} min';
  }

  Color _getAlertColor(String? alert) {
    if (alert == null) return AppColors.warmGraphite;
    switch (alert.toUpperCase()) {
      case 'DANGER':
      case 'CRITICAL':
        return AppColors.alertDanger;
      case 'CAUTION':
      case 'WARNING':
        return AppColors.alertCaution;
      case 'OK':
      case 'NOMINAL':
        return AppColors.alertOk;
      default:
        return AppColors.warmGraphite;
    }
  }

  IconData _getAlertIcon(String? alert) {
    if (alert == null) return Icons.info_outline_rounded;
    switch (alert.toUpperCase()) {
      case 'DANGER':
      case 'CRITICAL':
        return Icons.dangerous_rounded;
      case 'CAUTION':
      case 'WARNING':
        return Icons.warning_amber_rounded;
      case 'OK':
      case 'NOMINAL':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}
