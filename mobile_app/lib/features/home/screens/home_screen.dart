import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/dashboard.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/industrial_card.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/widgets/metric_readout.dart';
import '../../../shared/widgets/connectivity_banner.dart';
import '../../../shared/widgets/sahai_logo.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/motion/pulsing_beacon.dart';
import '../../../shared/motion/tactile_pressable.dart';
import '../../../shared/motion/acoustic_hero_widget.dart';
import '../../../shared/backgrounds/animated_screen_background.dart';
import '../../devices/screens/device_list_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../inspection/screens/inspection_screen.dart';
import '../../sessions/screens/session_list_screen.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Providers — real data from backend dashboard APIs
// ──────────────────────────────────────────────────────────────────────────────

final dashboardOverviewProvider =
    FutureProvider.autoDispose<DashboardOverview>((ref) async {
      final repo = ref.watch(dashboardRepositoryProvider);
      return repo.getOverview();
    });

final dashboardRecentActivityProvider =
    FutureProvider.autoDispose<List<RecentActivityItem>>((ref) async {
      final repo = ref.watch(dashboardRepositoryProvider);
      return repo.getRecentActivity(pageSize: 5);
    });

// ──────────────────────────────────────────────────────────────────────────────
// HomeScreen — 4-tab shell
// ──────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _HomeTab(onSwitchTab: _onDestinationSelected),
      const DeviceListScreen(),
      const _InspectTab(),
      const _HistoryTab(),
      const _SettingsTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ConnectivityBanner(),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.hub_outlined),
                selectedIcon: Icon(Icons.hub_rounded),
                label: 'Devices',
              ),
              NavigationDestination(
                icon: Icon(Icons.sensors_outlined),
                selectedIcon: Icon(Icons.sensors_rounded),
                label: 'Inspect',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'Sessions',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Home Tab (Overview) — uses REAL dashboard API data
// ──────────────────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  final ValueChanged<int> onSwitchTab;

  const _HomeTab({required this.onSwitchTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedDeviceId =
        ref.watch(selectedDeviceIdProvider) ?? 'SIH-DEV-01';

    // Real data from backend
    final overviewAsync = ref.watch(dashboardOverviewProvider);
    final activityAsync = ref.watch(dashboardRecentActivityProvider);
    final deviceStatusAsync = ref.watch(deviceStatusProvider);
    final latestTelemetryAsync = ref.watch(latestTelemetryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SahaiLogo(
              size: 28,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HAZGUARD',
                  style: AppTypography.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.carbon,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'DIAGNOSTIC WORKSTATION',
                  style: AppTypography.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.warmGraphite,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Overview',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () {
              ref.invalidate(dashboardOverviewProvider);
              ref.invalidate(dashboardRecentActivityProvider);
              ref.invalidate(deviceStatusProvider);
              ref.invalidate(latestTelemetryProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedScreenBackground(
        theme: ScreenBackgroundTheme.overview,
        intensity: 0.85,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardOverviewProvider);
            ref.invalidate(dashboardRecentActivityProvider);
            ref.invalidate(deviceStatusProvider);
            ref.invalidate(latestTelemetryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Greeting Banner ──
              StaggeredEntrance(
                index: 0,
                child: IndustrialCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.pureWhite,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.warmStone,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            (authState.username ?? 'U')[0].toUpperCase(),
                            style: AppTypography.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.burntOrange,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Welcome, ${authState.username ?? "Operator"}',
                                    style: AppTypography.spaceGrotesk(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.carbon,
                                    ),
                                  ),
                                ),
                                const StatusPill(
                                  label: 'AUTHENTICATED',
                                  type: StatusType.completed,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Acoustic Pipeline & Valve Inspection Aid',
                              style: AppTypography.inter(
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
                  ),
                ),
              ),

              // ── ACOUSTIC HERO — waveform driven by real telemetry ──
              StaggeredEntrance(
                index: 1,
                child: IndustrialCard(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: latestTelemetryAsync.when(
                    data: (telemetry) {
                      final rms = telemetry.event?.rms;
                      // Normalize RMS: ESP32 acoustic range 0–4096 ADC
                      final normalizedRms =
                          rms != null ? (rms / 4096.0).clamp(0.0, 1.0) : null;
                      final isLive = telemetry.isLive;
                      return AcousticHeroWidget(
                        isLive: isLive,
                        rmsValue: normalizedRms,
                        dataLabel: rms != null
                            ? '${rms.toStringAsFixed(0)} ADC RMS'
                            : null,
                        statusLabel: isLive
                            ? 'MONITORING ACTIVE'
                            : telemetry.hasData
                                ? 'LAST SESSION: ${telemetry.stalenessLabel.toUpperCase()}'
                                : 'AWAITING SESSION',
                      );
                    },
                    loading: () => const AcousticHeroWidget(
                      isLive: false,
                      statusLabel: 'LOADING TELEMETRY...',
                    ),
                    error: (err, stack) => const AcousticHeroWidget(
                      isLive: false,
                      statusLabel: 'BACKEND UNREACHABLE',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // ── Primary Device Status Card (REAL data from deviceStatusProvider) ──
              StaggeredEntrance(
                index: 1,
                child: deviceStatusAsync.when(
                  data: (status) => IndustrialCard(
                    title: 'Active Hardware Node',
                    subtitle: 'Target Diagnostic Telemetry Probe',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PulsingBeacon(
                          size: 9,
                          color: status.isOnline
                              ? AppColors.alertOk
                              : AppColors.warmGraphite,
                        ),
                        const SizedBox(width: 6),
                        StatusPill(
                          label: status.isOnline ? 'ONLINE' : 'OFFLINE',
                          type: status.isOnline
                              ? StatusType.online
                              : StatusType.offline,
                          showDot: false,
                        ),
                      ],
                    ),
                    onTap: () => context.go('/devices/$selectedDeviceId'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceElevated
                                    : AppColors.lightBurntOrange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.memory_rounded,
                                color: AppColors.burntOrange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedDeviceId,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    status.firmwareVersion != null
                                        ? 'FW ${status.firmwareVersion} · ESP32-S3 Acoustic Rig'
                                        : 'ESP32-S3 Acoustic Rig',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.warmGraphite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.warmGraphite,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.industrialIvory,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                status.isOnline
                                    ? 'Recent Activity: ${status.recentActivityCount} events'
                                    : status.lastSeenAt != null
                                        ? 'Last seen: ${_formatRelativeTime(status.lastSeenAt!)}'
                                        : 'Status: Never connected',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Text(
                                'Tap to inspect node →',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.burntOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  loading: () => IndustrialCard(
                    title: 'Active Hardware Node',
                    subtitle: 'Loading status...',
                    child: const SizedBox(
                      height: 48,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (err, _) => IndustrialCard(
                    title: 'Active Hardware Node',
                    subtitle: selectedDeviceId,
                    onTap: () => context.go('/devices/$selectedDeviceId'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.industrialIvory,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Status unavailable — tap to view details',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warmGraphite,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Telemetry Statistics (REAL data from dashboard overview API) ──
              StaggeredEntrance(
                index: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        'TELEMETRY METRICS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.warmGraphite,
                        ),
                      ),
                    ),
                    overviewAsync.when(
                      data: (overview) => Row(
                        children: [
                          Expanded(
                            child: MetricReadout(
                              label: 'Sessions',
                              value: '${overview.totalSessions}',
                              unit: 'runs',
                              icon: Icons.assignment_outlined,
                              onTap: () => onSwitchTab(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MetricReadout(
                              label: 'Nodes',
                              value: '${overview.totalDevices}',
                              unit: 'registered',
                              icon: Icons.devices_outlined,
                              onTap: () =>
                                  context.go('/devices/$selectedDeviceId'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MetricReadout(
                              label: 'Events',
                              value: '${overview.totalEvents}',
                              unit: 'logged',
                              icon: Icons.timeline_outlined,
                              onTap: () => onSwitchTab(4),
                            ),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox(
                        height: 80,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (err, _) => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.pureWhite,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.warmStone,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              size: 16,
                              color: AppColors.warmGraphite,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Metrics unavailable — connect to backend to view live statistics',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warmGraphite,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Workflow Actions ──
              StaggeredEntrance(
                index: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'WORKFLOW ACTIONS',
                        style: AppTypography.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.warmGraphite,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TactilePressable(
                            onTap: () => onSwitchTab(2),
                            child: IndustrialCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.burntOrange.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.radar_rounded,
                                      color: AppColors.burntOrange,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Live Inspection',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Stream Real-Time FFT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.warmGraphite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TactilePressable(
                            onTap: () => onSwitchTab(3),
                            child: IndustrialCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkSurfaceElevated
                                          : AppColors.softSand.withValues(
                                              alpha: 0.4,
                                            ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.history_edu_rounded,
                                      color: AppColors.darkBurntOrange,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Session Archive',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Audit Past Diagnostics',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.warmGraphite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TactilePressable(
                      onTap: () => context.push('/events'),
                      child: IndustrialCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceElevated
                                    : AppColors.softSand.withValues(
                                        alpha: 0.4,
                                      ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.timeline_rounded,
                                color: AppColors.darkBurntOrange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Event Timeline',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'View diagnostic event history',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.warmGraphite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.warmGraphite,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TactilePressable(
                      onTap: () => context.push('/assessments'),
                      child: IndustrialCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.burntOrange.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.assignment_turned_in_rounded,
                                color: AppColors.burntOrange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vocational Skill Evaluations',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'SIH26244 Rubrics • Trainee Competency Scorecard',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.warmGraphite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.warmGraphite,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Recent Activity (REAL data from dashboard/recent-activity API) ──
              StaggeredEntrance(
                index: 4,
                child: IndustrialCard(
                  title: 'Recent Diagnostic Events',
                  subtitle: 'Latest recorded telemetry from backend',
                  trailing: TextButton(
                    onPressed: () => onSwitchTab(4),
                    child: const Text('View All'),
                  ),
                  child: activityAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 18,
                                color: AppColors.warmGraphite,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'No recent activity — press the BOOT button on the device to start a session.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warmGraphite,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: items.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final isAlert = item.details['alert'] == 'DANGER' ||
                              item.details['alert'] == 'CAUTION';
                          return Column(
                            children: [
                              if (idx > 0) const Divider(height: 1),
                              _buildActivityTile(
                                context,
                                icon: item.type == 'session'
                                    ? Icons.play_circle_outline_rounded
                                    : isAlert
                                        ? Icons.warning_amber_rounded
                                        : Icons.sensors_rounded,
                                iconColor: item.type == 'session'
                                    ? AppColors.alertOk
                                    : isAlert
                                        ? AppColors.alertCaution
                                        : AppColors.burntOrange,
                                title: item.title,
                                time: _formatRelativeTime(item.timestamp),
                                alert: isAlert ? item.details['alert'] as String? : null,
                              ),
                            ],
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 60,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (err, _) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 18,
                            color: AppColors.warmGraphite,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Recent activity unavailable — connect to backend to view live data.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.warmGraphite,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
    String? alert,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.warmGraphite,
                  ),
                ),
              ],
            ),
          ),
          if (alert != null)
            StatusPill(
              label: alert,
              type: alert == 'DANGER'
                  ? StatusType.danger
                  : StatusType.caution,
            ),
        ],
      ),
    );
  }

  /// Formats a [DateTime] as a human-readable relative string (e.g. "2 hours ago").
  static String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt.isUtc ? dt.toLocal() : dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt.isUtc ? dt.toLocal() : dt);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Tab wrapper widgets
// ──────────────────────────────────────────────────────────────────────────────

class _InspectTab extends StatelessWidget {
  const _InspectTab();

  @override
  Widget build(BuildContext context) {
    return const InspectionScreen();
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return const SessionListScreen();
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}
