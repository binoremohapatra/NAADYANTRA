import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/industrial_card.dart';
import '../../../shared/widgets/industrial_button.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/widgets/sahai_logo.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/backgrounds/animated_screen_background.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedDevice = ref.watch(selectedDeviceIdProvider) ?? 'SIH-DEV-01';

    return Scaffold(
      appBar: AppBar(title: const Text('WORKSTATION SETTINGS')),
      body: AnimatedScreenBackground(
        theme: ScreenBackgroundTheme.minimalTuning,
        intensity: 0.7,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Operator Profile Card
          StaggeredEntrance(
            index: 0,
            child: IndustrialCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.pureWhite,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.burntOrange,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        (authState.username ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.burntOrange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                authState.username ?? 'Operator',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const StatusPill(
                              label: 'AUTHENTICATED',
                              type: StatusType.completed,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Certified Diagnostic Specialist',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warmGraphite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Hardware & Telemetry Link Section
          StaggeredEntrance(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('HARDWARE TELEMETRY LINK', isDark),
                IndustrialCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.memory_rounded,
                        title: 'Assigned Diagnostic Node',
                        subtitle: selectedDevice,
                        trailing: const StatusPill(
                          label: 'LINKED',
                          type: StatusType.online,
                          showDot: false,
                        ),
                        onTap: () => _showDeviceSelectionDialog(context, ref),
                      ),
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.alt_route_rounded,
                        title: 'FastAPI Backend Host',
                        subtitle: AppConfig.defaultApiBaseUrl,
                        trailing: const StatusPill(
                          label: 'ACTIVE',
                          type: StatusType.ok,
                          showDot: false,
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Endpoint configured via AppConfig.defaultApiBaseUrl',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.speed_rounded,
                        title: 'Acoustic Sampling Frequency',
                        subtitle: '192.0 kHz (16-bit DMA Ring Buffer)',
                        trailing: const StatusPill(
                          label: 'LOCKED',
                          type: StatusType.neutral,
                          showDot: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Workstation Storage & Diagnostics
          StaggeredEntrance(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'WORKSTATION STORAGE & DIAGNOSTICS',
                  isDark,
                ),
                IndustrialCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.layers_outlined,
                        title: 'Offline Telemetry Cache',
                        subtitle: 'SQLite Local Database',
                        trailing: TextButton(
                          onPressed: () => _showPurgeCacheDialog(context, ref),
                          child: const Text(
                            'Purge Cache',
                            style: TextStyle(
                              color: AppColors.alertDanger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'Vocational Training Evaluations',
                        subtitle:
                            'View trainee grading rubrics & skill reports',
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.warmGraphite,
                        ),
                        onTap: () => context.push('/assessments'),
                      ),
                      const Divider(),
                      _buildSettingsTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Field Guide & Troubleshooting',
                        subtitle:
                            'Hardware rigging, sensor semantics & safety protocols',
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.warmGraphite,
                        ),
                        onTap: () => context.push('/help'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Session Control / Sign Out
          StaggeredEntrance(
            index: 3,
            child: Column(
              children: [
                IndustrialButton(
                  label: 'Disconnect & Sign Out',
                  icon: Icons.power_settings_new_rounded,
                  variant: IndustrialButtonVariant.danger,
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Compliance & Build Watermark
                Center(
                  child: Column(
                    children: [
                      const SahaiLogo(size: 32),
                      const SizedBox(height: 10),
                      Text(
                        'SAHAI FIELD DIAGNOSTICS PLATFORM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.warmGraphite,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Build 1.0.0+1 • ESP32-S3 Acoustic RIG Engine',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextSecondary.withValues(
                                  alpha: 0.7,
                                )
                              : AppColors.warmGraphite.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: isDark ? AppColors.darkTextSecondary : AppColors.warmGraphite,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.burntOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.burntOrange, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warmGraphite,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  void _showDeviceSelectionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Select Hardware Node',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Consumer(
            builder: (context, ref, child) {
              final devicesAsync = ref.watch(devicesProvider);
              return devicesAsync.when(
                data: (paginatedResponse) {
                  if (paginatedResponse.items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No probe nodes currently paired.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: paginatedResponse.items.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final device = paginatedResponse.items[index];
                      final isSelected =
                          ref.watch(selectedDeviceIdProvider) ==
                          device.deviceId;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.memory_rounded,
                          color: isSelected
                              ? AppColors.burntOrange
                              : AppColors.warmGraphite,
                        ),
                        title: Text(
                          device.name ?? device.deviceId,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Node ID: ${device.deviceId} • ${device.isActive ? "online" : "offline"}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.burntOrange,
                              )
                            : null,
                        onTap: () {
                          ref.read(selectedDeviceIdProvider.notifier).state =
                              device.deviceId;
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Hardware target switched to ${device.deviceId}',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, _) => Text(
                  'Failed to fetch devices: $error',
                  style: const TextStyle(color: AppColors.alertDanger),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _showPurgeCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Purge Local Telemetry Cache?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will clear locally cached events and unsynced diagnostics from SQLite. Server records will remain untouched.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertDanger,
              foregroundColor: AppColors.pureWhite,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Local telemetry cache cleared successfully.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Purge Cache'),
          ),
        ],
      ),
    );
  }
}
