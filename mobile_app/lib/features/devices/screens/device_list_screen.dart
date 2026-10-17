import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion_tokens.dart';
import '../../../shared/models/device.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/motion/tactile_pressable.dart';
import '../../../shared/motion/pulsing_beacon.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/backgrounds/naadyantra_animated_background.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Device List Screen — premium device inventory with search, filter, sort
// ──────────────────────────────────────────────────────────────────────────────

enum _DeviceFilter { all, online, offline, unknown }

enum _DeviceSort { lastSeen, name }

class DeviceListScreen extends ConsumerStatefulWidget {
  const DeviceListScreen({super.key});

  @override
  ConsumerState<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends ConsumerState<DeviceListScreen> {
  final _searchController = TextEditingController();
  _DeviceFilter _filter = _DeviceFilter.all;
  _DeviceSort _sort = _DeviceSort.lastSeen;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Device> _applyFilterSort(List<Device> devices) {
    var filtered = devices.where((d) {
      // Search
      if (_searchQuery.isNotEmpty) {
        final matchName = (d.name ?? '').toLowerCase().contains(_searchQuery);
        final matchId = d.deviceId.toLowerCase().contains(_searchQuery);
        if (!matchName && !matchId) return false;
      }
      // Status filter
      switch (_filter) {
        case _DeviceFilter.all:
          return true;
        case _DeviceFilter.online:
          return d.connectivityStatus == 'online';
        case _DeviceFilter.offline:
          return d.connectivityStatus == 'offline';
        case _DeviceFilter.unknown:
          return d.connectivityStatus == 'unknown';
      }
    }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (_sort) {
        case _DeviceSort.lastSeen:
          final aTime = a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime); // newest first
        case _DeviceSort.name:
          return (a.name ?? a.deviceId).compareTo(b.name ?? b.deviceId);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DEVICE INVENTORY',
              style: AppTypography.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.pureWhite : AppColors.carbon,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Registered hardware nodes',
              style: AppTypography.inter(
                fontSize: 10,
                color: isDark ? AppColors.subtleGray : AppColors.warmGraphite,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        actions: [
          // Sort toggle
          PopupMenuButton<_DeviceSort>(
            icon: const Icon(Icons.sort_rounded, size: 20),
            tooltip: 'Sort',
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _DeviceSort.lastSeen,
                child: Text('Sort: Last Seen'),
              ),
              const PopupMenuItem(
                value: _DeviceSort.name,
                child: Text('Sort: Name'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(devicesProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: NaadyantraAnimatedBackground(
        kind: NaadyantraBackgroundKind.deviceInventory,
        lightScrimOpacity: 0.58,
        darkScrimOpacity: 0.50,
        child: Column(
          children: [
            // ── Search + Filter bar ──
            Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: _searchController,
                    style: AppTypography.inter(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.carbon,
                    ),
                    cursorColor: AppColors.burntOrange,
                    decoration: InputDecoration(
                      hintText: 'Search by name or device ID...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.subtleGray
                            : AppColors.warmGraphite,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: isDark
                            ? AppColors.softSand
                            : AppColors.warmGraphite,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: isDark
                                    ? AppColors.softSand
                                    : AppColors.warmGraphite,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xF21C1E20)
                          : AppColors.pureWhite.withValues(alpha: 0.95),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFF3A3D40)
                              : AppColors.warmStone,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.burntOrange,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _DeviceFilter.values.map((f) {
                        final isSelected = _filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: _filterLabel(f),
                            selected: isSelected,
                            onTap: () => setState(() => _filter = f),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: isDark ? const Color(0xFF2E2C29) : AppColors.warmStone,
            ),

            // ── Device list ──
            Expanded(
              child: devicesAsync.when(
                loading: () => const IndustrialLoadingView(
                  message: 'Loading registered devices...',
                ),
                error: (err, _) => IndustrialErrorView(
                  title: 'Device Inventory Unavailable',
                  message: 'Could not retrieve device list from backend. Check your connection.',
                  onRetry: () => ref.invalidate(devicesProvider),
                ),
                data: (response) {
                  final devices = response.items;
                  final filtered = _applyFilterSort(devices);

                  if (devices.isEmpty) {
                    return IndustrialEmptyView(
                      icon: Icons.hub_outlined,
                      title: 'No Devices Registered',
                      message: 'No hardware nodes have been registered with the backend yet.\nConfigure your ESP32 device and connect it to the network.',
                      actionLabel: 'Refresh',
                      onAction: () => ref.invalidate(devicesProvider),
                    );
                  }

                  if (filtered.isEmpty) {
                    return IndustrialEmptyView(
                      icon: Icons.search_off_rounded,
                      title: 'No Matching Devices',
                      message:
                          'No devices match your current search or filter.',
                      actionLabel: 'Clear Filters',
                      onAction: () {
                        _searchController.clear();
                        setState(() => _filter = _DeviceFilter.all);
                      },
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(devicesProvider),
                    color: AppColors.burntOrange,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final device = filtered[index];
                        return StaggeredEntrance(
                          index: index,
                          child: _DeviceCard(
                            device: device,
                            onTap: () {
                              ref
                                      .read(selectedDeviceIdProvider.notifier)
                                      .state =
                                  device.deviceId;
                              context.push('/devices/${device.deviceId}');
                            },
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
      ),
    );
  }

  String _filterLabel(_DeviceFilter f) {
    switch (f) {
      case _DeviceFilter.all:
        return 'All';
      case _DeviceFilter.online:
        return 'Online';
      case _DeviceFilter.offline:
        return 'Offline';
      case _DeviceFilter.unknown:
        return 'Unknown';
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Filter Chip
// ──────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: MotionTokens.durationFast,
        curve: MotionTokens.curveStandard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.burntOrange
              : (isDark ? AppColors.darkSurfaceElevated : AppColors.pureWhite),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.burntOrange
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

// ──────────────────────────────────────────────────────────────────────────────
// Device Card — compact list item with status, last seen, firmware
// ──────────────────────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = device.connectivityStatus;
    final isOnline = status == 'online';
    final isUnknown = status == 'unknown';

    final statusColor = isOnline
        ? AppColors.alertOk
        : isUnknown
        ? AppColors.warmGraphite
        : AppColors.alertDanger;

    final statusType = isOnline
        ? StatusType.online
        : isUnknown
        ? StatusType.neutral
        : StatusType.offline;

    return TactilePressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOnline
                ? AppColors.alertOk.withValues(alpha: 0.25)
                : isDark
                ? AppColors.darkBorder
                : AppColors.warmStone,
            width: 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AppColors.carbon.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Status beacon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.memory_rounded, size: 22, color: statusColor),
                    if (isOnline)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: PulsingBeacon(size: 7, color: AppColors.alertOk),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.name ?? device.deviceId,
                            style: AppTypography.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.carbon,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusPill(
                          label: status.toUpperCase(),
                          type: statusType,
                          showDot: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Text(
                          device.deviceId,
                          style: AppTypography.mono(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.warmGraphite,
                          ),
                        ),
                        if (device.firmwareVersion != null) ...[
                          Text(
                            ' · FW ${device.firmwareVersion}',
                            style: AppTypography.inter(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.warmGraphite,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Last seen
                    Row(
                      children: [
                        Icon(
                          isOnline
                              ? Icons.wifi_rounded
                              : Icons.wifi_off_rounded,
                          size: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.subtleGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          device.lastSeenAt != null
                              ? _lastSeenLabel(device.lastSeenAt!)
                              : 'Never connected',
                          style: AppTypography.inter(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.subtleGray,
                          ),
                        ),
                        if (!device.isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warmGraphite.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'INACTIVE',
                              style: AppTypography.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warmGraphite,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.warmGraphite,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _lastSeenLabel(DateTime dt) {
    final now = DateTime.now();
    final local = dt.isUtc ? dt.toLocal() : dt;
    final diff = now.difference(local);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(local);
  }
}
