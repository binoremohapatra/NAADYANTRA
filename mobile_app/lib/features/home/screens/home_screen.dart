import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion_tokens.dart';
import '../../../shared/models/dashboard.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/connectivity_banner.dart';
import '../../../shared/widgets/industrial_card.dart';
import '../../../shared/widgets/interactive_metric_card.dart';
import '../../../shared/widgets/naadyantra_nav_bar.dart';
import '../../../shared/widgets/sahai_logo.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/motion/acoustic_hero_widget.dart';
import '../../../shared/motion/pulsing_beacon.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/motion/tactile_pressable.dart';
import '../../../shared/backgrounds/naadyantra_animated_background.dart';
import '../../devices/screens/device_list_screen.dart';
import '../../inspection/screens/inspection_screen.dart';
import '../../sessions/screens/session_list_screen.dart';
import '../../settings/screens/settings_screen.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Dashboard API Providers
// ──────────────────────────────────────────────────────────────────────────────

final dashboardOverviewProvider = FutureProvider.autoDispose<DashboardOverview>(
  (ref) async {
    final repo = ref.watch(dashboardRepositoryProvider);
    return repo.getOverview();
  },
);

final dashboardRecentActivityProvider =
    FutureProvider.autoDispose<List<RecentActivityItem>>((ref) async {
      final repo = ref.watch(dashboardRepositoryProvider);
      return repo.getRecentActivity(pageSize: 5);
    });

// ──────────────────────────────────────────────────────────────────────────────
// HomeScreen — 5-tab shell with premium NaadyantraNavBar
// ──────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _tabChangeCtrl;
  late Animation<double> _tabFadeAnim;

  @override
  void initState() {
    super.initState();
    _tabChangeCtrl = AnimationController(
      vsync: this,
      duration: MotionTokens.durationFast,
    );
    _tabFadeAnim = CurvedAnimation(
      parent: _tabChangeCtrl,
      curve: Curves.easeOutCubic,
    );
    _tabChangeCtrl.forward();
  }

  @override
  void dispose() {
    _tabChangeCtrl.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) return;
    _tabChangeCtrl
        .reverse()
        .then((_) {
          if (mounted) {
            setState(() => _selectedIndex = index);
          }
        })
        .then((_) {
          if (mounted) _tabChangeCtrl.forward();
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
      body: FadeTransition(
        opacity: _tabFadeAnim,
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ConnectivityBanner(),
          NaadyantraNavBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _HomeTab (Overview) — Interactive premium home experience
// ──────────────────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  final ValueChanged<int> onSwitchTab;

  const _HomeTab({required this.onSwitchTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeDeviceId = ref.watch(activeDeviceIdProvider);
    final selectedDeviceId = activeDeviceId ?? '—';

    final overviewAsync = ref.watch(dashboardOverviewProvider);
    final activityAsync = ref.watch(dashboardRecentActivityProvider);
    final deviceStatusAsync = ref.watch(deviceStatusProvider);
    final latestTelemetryAsync = ref.watch(latestTelemetryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const SahaiLogo(size: 28),
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
                  'ACOUSTIC DIAGNOSTIC PLATFORM',
                  style: AppTypography.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
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
          // Refresh
          _AppBarAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh Overview',
            onTap: () {
              ref.invalidate(dashboardOverviewProvider);
              ref.invalidate(dashboardRecentActivityProvider);
              ref.invalidate(deviceStatusProvider);
              ref.invalidate(latestTelemetryProvider);
            },
          ),
          // Field guide
          _AppBarAction(
            icon: Icons.help_outline_rounded,
            tooltip: 'Field Guide',
            onTap: () => context.push('/help'),
          ),
          // Sign out
          _AppBarAction(
            icon: Icons.logout_rounded,
            tooltip: 'Sign Out',
            onTap: () async {
              await ref.read(authStateProvider.notifier).logout();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: NaadyantraAnimatedBackground(
        kind: NaadyantraBackgroundKind.homeOverview,
        lightScrimOpacity: 0.88,
        darkScrimOpacity: 0.70,
        child: RefreshIndicator(
          color: AppColors.burntOrange,
          onRefresh: () async {
            ref.invalidate(dashboardOverviewProvider);
            ref.invalidate(dashboardRecentActivityProvider);
            ref.invalidate(deviceStatusProvider);
            ref.invalidate(latestTelemetryProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── Welcome Header ──
              StaggeredEntrance(
                index: 0,
                child: _WelcomeHeader(
                  username: authState.username ?? 'Operator',
                  isDark: isDark,
                ),
              ),

              // ── Acoustic Hero ──
              StaggeredEntrance(
                index: 1,
                child: _AcousticHeroSection(
                  latestTelemetryAsync: latestTelemetryAsync,
                  selectedDeviceId: activeDeviceId,
                  onPrimaryTap: () => onSwitchTab(2),
                  onSecondaryTap: () {
                    if (activeDeviceId != null && activeDeviceId.isNotEmpty) {
                      context.go('/devices/$activeDeviceId');
                    } else {
                      onSwitchTab(1);
                    }
                  },
                  isDark: isDark,
                ),
              ),

              // ── Device Status Card ──
              StaggeredEntrance(
                index: 2,
                child: deviceStatusAsync.when(
                  data: (status) => _DeviceStatusCard(
                    status: status,
                    selectedDeviceId: selectedDeviceId,
                    isDark: isDark,
                    onTap: () {
                      if (activeDeviceId != null && activeDeviceId.isNotEmpty) {
                        context.go('/devices/$activeDeviceId');
                      } else {
                        onSwitchTab(1);
                      }
                    },
                  ),
                  loading: () => _DeviceStatusSkeleton(),
                  error: (e, _) => _DeviceStatusError(
                    deviceId: selectedDeviceId,
                    onTap: () => onSwitchTab(1),
                    isDark: isDark,
                  ),
                ),
              ),

              // ── Telemetry Metrics ──
              StaggeredEntrance(
                index: 3,
                child: _TelemetryMetricsSection(
                  overviewAsync: overviewAsync,
                  isDark: isDark,
                  onSessionsTap: () => onSwitchTab(3),
                  onDevicesTap: () => onSwitchTab(1),
                  onEventsTap: () => context.push('/events'),
                ),
              ),

              // ── Quick Actions ──
              StaggeredEntrance(
                index: 4,
                child: _QuickActionsSection(
                  isDark: isDark,
                  onInspect: () => onSwitchTab(2),
                  onSessions: () => onSwitchTab(3),
                  onEvents: () => context.push('/events'),
                  onAssessments: () => context.push('/assessments'),
                ),
              ),

              // ── Recent Activity ──
              StaggeredEntrance(
                index: 5,
                child: _RecentActivitySection(
                  activityAsync: activityAsync,
                  isDark: isDark,
                  onViewAll: () => context.push('/events'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Component: AppBar Icon Action
// ──────────────────────────────────────────────────────────────────────────────

class _AppBarAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_AppBarAction> createState() => _AppBarActionState();
}

class _AppBarActionState extends State<_AppBarAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionTokens.durationInstant,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Tooltip(
          message: widget.tooltip,
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 20),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Component: Welcome Header
// ──────────────────────────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  final String username;
  final bool isDark;

  const _WelcomeHeader({required this.username, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.warmStone,
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.carbon.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.burntOrange.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.burntOrange.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                username[0].toUpperCase(),
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
                Text(
                  'Welcome, $username',
                  style: AppTypography.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.carbon,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Acoustic pipeline & valve inspection aid',
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
          const StatusPill(
            label: 'ACTIVE',
            type: StatusType.online,
            showDot: true,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Component: Acoustic Hero Section — interactive signature element
// ──────────────────────────────────────────────────────────────────────────────

class _AcousticHeroSection extends StatelessWidget {
  final AsyncValue<dynamic> latestTelemetryAsync;
  final String? selectedDeviceId;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;
  final bool isDark;

  const _AcousticHeroSection({
    required this.latestTelemetryAsync,
    this.selectedDeviceId,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.warmStone,
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.carbon.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          // Waveform area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: latestTelemetryAsync.when(
              data: (telemetry) {
                final rms = telemetry.event?.rms;
                final normalizedRms = rms != null
                    ? (rms / 4096.0).clamp(0.0, 1.0)
                    : null;
                final isLive = telemetry.isLive;
                return AcousticHeroWidget(
                  isLive: isLive,
                  isInstrumentPanel: true,
                  deviceId: selectedDeviceId,
                  freshnessLabel: isLive
                      ? 'LIVE STREAM'
                      : telemetry.hasData
                      ? telemetry.stalenessLabel.toUpperCase()
                      : 'STANDBY',
                  rmsValue: normalizedRms,
                  dataLabel: rms != null
                      ? '${rms.toStringAsFixed(0)} ADC RMS'
                      : null,
                  statusLabel: isLive
                      ? 'MONITORING ACTIVE'
                      : telemetry.hasData
                      ? 'LAST TELEMETRY: ${telemetry.stalenessLabel.toUpperCase()}'
                      : 'AWAITING SESSION',
                );
              },
              loading: () => AcousticHeroWidget(
                isLive: false,
                isInstrumentPanel: true,
                deviceId: selectedDeviceId,
                statusLabel: 'LOADING TELEMETRY...',
              ),
              error: (e, _) => AcousticHeroWidget(
                isLive: false,
                isInstrumentPanel: true,
                deviceId: selectedDeviceId,
                statusLabel: 'BACKEND UNREACHABLE',
              ),
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Primary: Live Inspection
                Expanded(
                  child: _HeroAction(
                    icon: Icons.radar_rounded,
                    label: 'Live Inspection',
                    accent: AppColors.burntOrange,
                    isPrimary: true,
                    isDark: isDark,
                    onTap: onPrimaryTap,
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                ),
                // Secondary: Device Details
                Expanded(
                  child: _HeroAction(
                    icon: Icons.memory_rounded,
                    label: 'Device Details',
                    accent: AppColors.warmGraphite,
                    isPrimary: false,
                    isDark: isDark,
                    onTap: onSecondaryTap,
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

class _HeroAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool isPrimary;
  final bool isDark;
  final VoidCallback onTap;

  const _HeroAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isPrimary,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_HeroAction> createState() => _HeroActionState();
}

class _HeroActionState extends State<_HeroAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionTokens.durationInstant,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _ctrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _ctrl.reverse();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: MotionTokens.durationInstant,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.accent.withValues(alpha: widget.isPrimary ? 0.08 : 0.04)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 18, color: widget.accent),
            const SizedBox(width: 7),
            Text(
              widget.label,
              style: AppTypography.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.isPrimary
                    ? widget.accent
                    : (widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.warmGraphite),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Component: Device Status Card
// ──────────────────────────────────────────────────────────────────────────────

class _DeviceStatusCard extends StatelessWidget {
  final dynamic status;
  final String selectedDeviceId;
  final bool isDark;
  final VoidCallback onTap;

  const _DeviceStatusCard({
    required this.status,
    required this.selectedDeviceId,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDevice = selectedDeviceId != '—' && status.deviceId != '—';

    return TactilePressable(
      onTap: onTap,
      child: IndustrialCard(
        title: hasDevice ? 'Active Hardware Node' : 'No Hardware Node Linked',
        subtitle: hasDevice
            ? 'Target Diagnostic Telemetry Probe'
            : 'Connect or provision an ESP32 sensor rig',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulsingBeacon(
              size: 9,
              color: hasDevice && status.isOnline
                  ? AppColors.alertOk
                  : AppColors.warmGraphite,
            ),
            const SizedBox(width: 6),
            StatusPill(
              label: hasDevice
                  ? (status.isOnline ? 'ONLINE' : 'OFFLINE')
                  : 'UNPAIRED',
              type: hasDevice
                  ? (status.isOnline ? StatusType.online : StatusType.offline)
                  : StatusType.offline,
              showDot: false,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.lightBurntOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasDevice ? Icons.memory_rounded : Icons.sensors_off_rounded,
                    color: AppColors.burntOrange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasDevice ? selectedDeviceId : 'No Node Linked',
                        style: AppTypography.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasDevice
                            ? (status.firmwareVersion != null
                                ? 'FW ${status.firmwareVersion} · ESP32-S3'
                                : 'ESP32-S3 Acoustic Sensor Rig')
                            : 'Tap to view device inventory',
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.warmGraphite,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    hasDevice
                        ? (status.isOnline
                            ? '${status.recentActivityCount} recent events'
                            : status.lastSeenAt != null
                            ? 'Last seen: ${_relativeTime(status.lastSeenAt!)}'
                            : 'Never connected')
                        : 'Awaiting hardware probe connection',
                    style: AppTypography.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.warmGraphite,
                    ),
                  ),
                  Text(
                    hasDevice ? 'Tap to inspect →' : 'Open Devices →',
                    style: AppTypography.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.burntOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt.isUtc ? dt.toLocal() : dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _DeviceStatusSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.warmStone,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 44, height: 44, radius: 10),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 120, height: 14, radius: 4),
                    const SizedBox(height: 6),
                    ShimmerBox(width: 180, height: 11, radius: 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ShimmerBox(width: double.infinity, height: 36, radius: 8),
        ],
      ),
    );
  }
}

class _DeviceStatusError extends StatelessWidget {
  final String deviceId;
  final VoidCallback onTap;
  final bool isDark;

  const _DeviceStatusError({
    required this.deviceId,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return TactilePressable(
      onTap: onTap,
      child: IndustrialCard(
        title: 'Active Hardware Node',
        subtitle: deviceId,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.alertDanger.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.alertDanger.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 16,
                color: AppColors.alertDanger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Device status unavailable — tap to view node details',
                  style: AppTypography.inter(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.warmGraphite,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Component: Telemetry Metrics Section — 3 interactive metric cards
// ──────────────────────────────────────────────────────────────────────────────

class _TelemetryMetricsSection extends StatelessWidget {
  final AsyncValue<DashboardOverview> overviewAsync;
  final bool isDark;
  final VoidCallback onSessionsTap;
  final VoidCallback onDevicesTap;
  final VoidCallback onEventsTap;

  const _TelemetryMetricsSection({
    required this.overviewAsync,
    required this.isDark,
    required this.onSessionsTap,
    required this.onDevicesTap,
    required this.onEventsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('TELEMETRY METRICS', isDark: isDark),
        overviewAsync.when(
          data: (overview) => Row(
            children: [
              Expanded(
                child: InteractiveMetricCard(
                  label: 'Sessions',
                  value: '${overview.totalSessions}',
                  unit: 'runs',
                  icon: Icons.assignment_outlined,
                  accentColor: AppColors.darkBurntOrange,
                  explanation: 'Total number of acoustic monitoring sessions logged in the backend database.',
                  onTap: onSessionsTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InteractiveMetricCard(
                  label: 'Nodes',
                  value: '${overview.totalDevices}',
                  unit: 'registered',
                  icon: Icons.hub_outlined,
                  accentColor: AppColors.warmGraphite,
                  explanation: 'Number of ESP32-S3 hardware nodes registered in the system. Only provisioned devices appear here.',
                  onTap: onDevicesTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InteractiveMetricCard(
                  label: 'Events',
                  value: '${overview.totalEvents}',
                  unit: 'logged',
                  icon: Icons.timeline_outlined,
                  accentColor: AppColors.burntOrange,
                  explanation: 'Total diagnostic events recorded: acoustic readings, gas detections, proximity alerts and hazard classifications.',
                  onTap: onEventsTap,
                ),
              ),
            ],
          ),
          loading: () => Row(
            children: List.generate(
              3,
              (_) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 88,
                    radius: 12,
                  ),
                ),
              ),
            ),
          ),
          error: (e, _) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.warmStone,
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
                    'Metrics unavailable — connect to backend to view live statistics.',
                    style: AppTypography.inter(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.warmGraphite,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Component: Quick Actions Section
// ──────────────────────────────────────────────────────────────────────────────

class _QuickActionsSection extends StatelessWidget {
  final bool isDark;
  final VoidCallback onInspect;
  final VoidCallback onSessions;
  final VoidCallback onEvents;
  final VoidCallback onAssessments;

  const _QuickActionsSection({
    required this.isDark,
    required this.onInspect,
    required this.onSessions,
    required this.onEvents,
    required this.onAssessments,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('QUICK ACTIONS', isDark: isDark),
        // Top row — 2-up grid cards
        Row(
          children: [
            Expanded(
              child: _ActionGridCard(
                icon: Icons.radar_rounded,
                title: 'Live Inspection',
                subtitle: 'Stream Real-Time FFT',
                accent: AppColors.burntOrange,
                isDark: isDark,
                onTap: onInspect,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionGridCard(
                icon: Icons.history_edu_rounded,
                title: 'Session Archive',
                subtitle: 'Audit Past Diagnostics',
                accent: AppColors.darkBurntOrange,
                isDark: isDark,
                onTap: onSessions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Bottom row — full-width list rows
        _ActionListRow(
          icon: Icons.timeline_rounded,
          title: 'Event Timeline',
          subtitle: 'Browse diagnostic event history',
          isDark: isDark,
          onTap: onEvents,
        ),
        _ActionListRow(
          icon: Icons.assignment_turned_in_rounded,
          title: 'Vocational Skill Evaluations',
          subtitle: 'SIH26244 rubrics · Trainee competency scorecard',
          isDark: isDark,
          onTap: onAssessments,
          isLast: true,
        ),
      ],
    );
  }
}

class _ActionGridCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionGridCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ActionGridCard> createState() => _ActionGridCardState();
}

class _ActionGridCardState extends State<_ActionGridCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionTokens.durationInstant,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkSurface : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark ? AppColors.darkBorder : AppColors.warmStone,
              width: 1,
            ),
            boxShadow: widget.isDark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.carbon.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                style: AppTypography.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: widget.isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.carbon,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.subtitle,
                style: AppTypography.inter(
                  fontSize: 11,
                  color: widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.warmGraphite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionListRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;
  final bool isLast;

  const _ActionListRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
    this.isLast = false,
  });

  @override
  State<_ActionListRow> createState() => _ActionListRowState();
}

class _ActionListRowState extends State<_ActionListRow>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: MotionTokens.durationInstant,
        margin: EdgeInsets.only(bottom: widget.isLast ? 12 : 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _pressed
              ? (widget.isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.warmStone.withValues(alpha: 0.4))
              : (widget.isDark ? AppColors.darkSurface : AppColors.pureWhite),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDark ? AppColors.darkBorder : AppColors.warmStone,
            width: 1,
          ),
          boxShadow: widget.isDark
              ? null
              : [
                  BoxShadow(
                    color: AppColors.carbon.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.burntOrange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(widget.icon, color: AppColors.burntOrange, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppTypography.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.carbon,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: AppTypography.inter(
                      fontSize: 11,
                      color: widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.warmGraphite,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: widget.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.warmGraphite,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Component: Recent Activity Section — tappable event timeline preview
// ──────────────────────────────────────────────────────────────────────────────

class _RecentActivitySection extends StatelessWidget {
  final AsyncValue<List<RecentActivityItem>> activityAsync;
  final bool isDark;
  final VoidCallback onViewAll;

  const _RecentActivitySection({
    required this.activityAsync,
    required this.isDark,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SectionLabel('RECENT ACTIVITY', isDark: isDark)),
            TextButton.icon(
              onPressed: onViewAll,
              icon: const Icon(Icons.open_in_new_rounded, size: 13),
              label: Text(
                'View All',
                style: AppTypography.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.burntOrange,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.burntOrange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.warmStone,
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.carbon.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: activityAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return _EmptyActivityState(isDark: isDark);
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return _ActivityRow(
                      item: item,
                      isDark: isDark,
                      showDivider: idx < items.length - 1,
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ShimmerBox.row(),
                  ),
                ),
              ),
            ),
            error: (e, _) => _ActivityErrorState(isDark: isDark),
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatefulWidget {
  final RecentActivityItem item;
  final bool isDark;
  final bool showDivider;

  const _ActivityRow({
    required this.item,
    required this.isDark,
    required this.showDivider,
  });

  @override
  State<_ActivityRow> createState() => _ActivityRowState();
}

class _ActivityRowState extends State<_ActivityRow>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  Color _itemColor() {
    if (widget.item.type == 'session') return AppColors.alertOk;
    final alert = widget.item.details['alert'] as String? ?? '';
    if (alert == 'DANGER') return AppColors.alertDanger;
    if (alert == 'CAUTION') return AppColors.alertCaution;
    return AppColors.burntOrange;
  }

  IconData _itemIcon() {
    if (widget.item.type == 'session') return Icons.play_circle_outline_rounded;
    final alert = widget.item.details['alert'] as String? ?? '';
    if (alert == 'DANGER') return Icons.error_rounded;
    if (alert == 'CAUTION') return Icons.warning_amber_rounded;
    return Icons.sensors_rounded;
  }

  String _formatTs() {
    final now = DateTime.now();
    final dt = widget.item.timestamp.isUtc
        ? widget.item.timestamp.toLocal()
        : widget.item.timestamp;
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }

  void _showDetail(BuildContext context) {
    final accent = _itemColor();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ActivityDetailSheet(
        item: widget.item,
        accent: accent,
        isDark: widget.isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _itemColor();

    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            _showDetail(context);
          },
          onTapCancel: () => setState(() => _pressed = false),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: MotionTokens.durationInstant,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _pressed
                ? (widget.isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.warmStone.withValues(alpha: 0.3))
                : Colors.transparent,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_itemIcon(), color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: AppTypography.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.carbon,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.item.subtitle,
                        style: AppTypography.inter(
                          fontSize: 11,
                          color: widget.isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.warmGraphite,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTs(),
                      style: AppTypography.mono(
                        fontSize: 10,
                        color: widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.warmGraphite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color:
                          (widget.isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.warmGraphite)
                              .withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: widget.isDark ? AppColors.darkBorder : AppColors.warmStone,
          ),
      ],
    );
  }
}

class _ActivityDetailSheet extends StatelessWidget {
  final RecentActivityItem item;
  final Color accent;
  final bool isDark;

  const _ActivityDetailSheet({
    required this.item,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              item.title,
              style: AppTypography.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.carbon,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.subtitle,
              style: AppTypography.inter(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.warmGraphite,
              ),
            ),
            const SizedBox(height: 16),
            Divider(
              color: isDark ? AppColors.darkBorder : AppColors.warmStone,
              height: 1,
            ),
            const SizedBox(height: 16),
            _SheetRow(
              icon: Icons.access_time_rounded,
              label: 'Timestamp',
              value: DateFormat('d MMM yyyy, HH:mm:ss').format(
                item.timestamp.isUtc
                    ? item.timestamp.toLocal()
                    : item.timestamp,
              ),
              isDark: isDark,
            ),
            _SheetRow(
              icon: Icons.memory_rounded,
              label: 'Device',
              value: item.deviceId,
              isDark: isDark,
            ),
            if (item.traineeId != null)
              _SheetRow(
                icon: Icons.person_outline_rounded,
                label: 'Trainee',
                value: item.traineeId!,
                isDark: isDark,
              ),
            _SheetRow(
              icon: Icons.category_rounded,
              label: 'Type',
              value: item.type,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _SheetRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
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
            width: 80,
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
              style: AppTypography.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.carbon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivityState extends StatelessWidget {
  final bool isDark;
  const _EmptyActivityState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warmStone.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.sensors_off_rounded,
              size: 20,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.warmGraphite,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No recent activity — press the BOOT button on the device to start a session.',
              style: AppTypography.inter(
                fontSize: 12,
                height: 1.5,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.warmGraphite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityErrorState extends StatelessWidget {
  final bool isDark;
  const _ActivityErrorState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
              'Recent activity unavailable — connect to backend to view live data.',
              style: AppTypography.inter(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.warmGraphite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared: Section Label
// ──────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        text,
        style: AppTypography.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: isDark ? AppColors.darkTextSecondary : AppColors.warmGraphite,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Tab wrappers
// ──────────────────────────────────────────────────────────────────────────────

class _InspectTab extends StatelessWidget {
  const _InspectTab();

  @override
  Widget build(BuildContext context) => const InspectionScreen();
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) => const SessionListScreen();
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) => const SettingsScreen();
}
