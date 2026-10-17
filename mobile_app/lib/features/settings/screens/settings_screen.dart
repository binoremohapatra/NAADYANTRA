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
import '../../../shared/backgrounds/naadyantra_animated_background.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final activeDeviceId = ref.watch(activeDeviceIdProvider);
    final selectedDevice = activeDeviceId ?? 'No Node Linked';
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark
        ? const Color(0xF21C1E20)
        : AppColors.pureWhite.withValues(alpha: 0.95);
    final cardBorder = isDark ? const Color(0xFF3A3D40) : AppColors.warmStone;
    final dividerColor = isDark ? const Color(0xFF2E2C29) : AppColors.warmStone;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'WORKSTATION SETTINGS',
          style: AppTypography.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.pureWhite : AppColors.carbon,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: NaadyantraAnimatedBackground(
        kind: NaadyantraBackgroundKind.settings,
        lightScrimOpacity: 0.58,
        darkScrimOpacity: 0.50,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            // Operator Profile Card
            StaggeredEntrance(
              index: 0,
              child: IndustrialCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: cardBg,
                borderColor: cardBorder,
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF141413)
                            : AppColors.lightSurfaceSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.burntOrange,
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.burntOrange.withValues(alpha: 0.2),
                            blurRadius: 10,
                          ),
                        ],
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
                                  style: AppTypography.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.carbon,
                                    letterSpacing: 0.4,
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
                          Text(
                            'Certified Diagnostic Specialist',
                            style: TextStyle(
                              fontSize: 12,
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
            const SizedBox(height: 14),

            // Appearance & Theme Selector Section
            StaggeredEntrance(
              index: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('APPEARANCE & DISPLAY THEME', isDark),
                  IndustrialCard(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: cardBg,
                    borderColor: cardBorder,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.burntOrange.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.palette_outlined,
                                color: AppColors.burntOrange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Visual Environment',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.carbon,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Sets animated backgrounds and UI contrast',
                                    style: TextStyle(
                                      fontSize: 12,
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
                        const SizedBox(height: 16),
                        // 3-way Segmented Theme Selector
                        Row(
                          children: [
                            Expanded(
                              child: _ThemeOptionTile(
                                icon: Icons.light_mode_rounded,
                                label: 'Light',
                                isSelected: themeMode == ThemeMode.light,
                                isDarkTheme: isDark,
                                onTap: () => ref
                                    .read(themeModeProvider.notifier)
                                    .setThemeMode(ThemeMode.light),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ThemeOptionTile(
                                icon: Icons.dark_mode_rounded,
                                label: 'Dark',
                                isSelected: themeMode == ThemeMode.dark,
                                isDarkTheme: isDark,
                                onTap: () => ref
                                    .read(themeModeProvider.notifier)
                                    .setThemeMode(ThemeMode.dark),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ThemeOptionTile(
                                icon: Icons.brightness_auto_rounded,
                                label: 'System',
                                isSelected: themeMode == ThemeMode.system,
                                isDarkTheme: isDark,
                                onTap: () => ref
                                    .read(themeModeProvider.notifier)
                                    .setThemeMode(ThemeMode.system),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Hardware & Telemetry Link Section
            StaggeredEntrance(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('HARDWARE TELEMETRY LINK', isDark),
                  IndustrialCard(
                    padding: EdgeInsets.zero,
                    backgroundColor: cardBg,
                    borderColor: cardBorder,
                    child: Column(
                      children: [
                        _buildSettingsTile(
                          icon: Icons.memory_rounded,
                          title: 'Assigned Diagnostic Node',
                          subtitle: selectedDevice,
                          isDark: isDark,
                          trailing: StatusPill(
                            label: activeDeviceId != null ? 'LINKED' : 'UNLINKED',
                            type: activeDeviceId != null ? StatusType.online : StatusType.offline,
                            showDot: false,
                          ),
                          onTap: () => _showDeviceSelectionDialog(context, ref),
                        ),
                        Divider(color: dividerColor, height: 1, thickness: 1),
                        _buildSettingsTile(
                          icon: Icons.alt_route_rounded,
                          title: 'FastAPI Backend Host',
                          subtitle: AppConfig.defaultApiBaseUrl,
                          isDark: isDark,
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
                        Divider(color: dividerColor, height: 1, thickness: 1),
                        _buildSettingsTile(
                          icon: Icons.speed_rounded,
                          title: 'Acoustic Sampling Frequency',
                          subtitle: '192.0 kHz (16-bit DMA Ring Buffer)',
                          isDark: isDark,
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
            const SizedBox(height: 14),

            // Workstation Storage & Diagnostics
            StaggeredEntrance(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    'WORKSTATION STORAGE & DIAGNOSTICS',
                    isDark,
                  ),
                  IndustrialCard(
                    padding: EdgeInsets.zero,
                    backgroundColor: cardBg,
                    borderColor: cardBorder,
                    child: Column(
                      children: [
                        _buildSettingsTile(
                          icon: Icons.layers_outlined,
                          title: 'Offline Telemetry Cache',
                          subtitle: 'SQLite Local Database',
                          isDark: isDark,
                          trailing: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                _showPurgeCacheDialog(context, ref),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.alertDanger.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.alertDanger.withValues(
                                    alpha: 0.4,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'PURGE CACHE',
                                style: TextStyle(
                                  color: AppColors.alertDanger,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Divider(color: dividerColor, height: 1, thickness: 1),
                        _buildSettingsTile(
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'Vocational Training Evaluations',
                          subtitle:
                              'View trainee grading rubrics & skill reports',
                          isDark: isDark,
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: isDark
                                ? AppColors.softSand
                                : AppColors.warmGraphite,
                          ),
                          onTap: () => context.push('/assessments'),
                        ),
                        Divider(color: dividerColor, height: 1, thickness: 1),
                        _buildSettingsTile(
                          icon: Icons.help_outline_rounded,
                          title: 'Field Guide & Troubleshooting',
                          subtitle: 'Hardware rigging, sensor semantics & safety protocols',
                          isDark: isDark,
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: isDark
                                ? AppColors.softSand
                                : AppColors.warmGraphite,
                          ),
                          onTap: () => context.push('/help'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Session Control / Sign Out
            StaggeredEntrance(
              index: 4,
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
                  const SizedBox(height: 28),

                  // Compliance & Build Watermark
                  Center(
                    child: Column(
                      children: [
                        const SahaiLogo(size: 34),
                        const SizedBox(height: 10),
                        Text(
                          'HAZGUARD FIELD DIAGNOSTICS PLATFORM',
                          style: AppTypography.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: isDark
                                ? AppColors.softSand
                                : AppColors.carbon,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Build 1.0.0+1 • ESP32-S3 Acoustic RIG Engine',
                          style: AppTypography.mono(
                            fontSize: 9.5,
                            color: isDark
                                ? AppColors.subtleGray.withValues(alpha: 0.75)
                                : AppColors.warmGraphite,
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
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.burntOrange,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTypography.mono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: isDark ? AppColors.softSand : AppColors.warmGraphite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required bool isDark,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.burntOrange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.burntOrange, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.carbon,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.warmGraphite,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
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
                          ref.watch(activeDeviceIdProvider) ==
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

class _ThemeOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDarkTheme;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDarkTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppColors.burntOrange
        : (isDarkTheme
              ? const Color(0xFF282724)
              : AppColors.lightSurfaceSecondary);

    final textColor = isSelected
        ? AppColors.pureWhite
        : (isDarkTheme ? AppColors.darkTextPrimary : AppColors.carbon);

    final borderColor = isSelected
        ? AppColors.burntOrange
        : (isDarkTheme ? const Color(0xFF383531) : AppColors.warmStone);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.burntOrange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
