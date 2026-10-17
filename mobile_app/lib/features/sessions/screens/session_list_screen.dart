import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion_tokens.dart';
import '../../../shared/models/session.dart';
import '../../../shared/models/common.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/industrial_card.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/motion/tactile_pressable.dart';
import '../../../shared/backgrounds/naadyantra_animated_background.dart';

final sessionsProvider =
    FutureProvider.family<PaginatedResponse<Session>, String>((
      ref,
      params,
    ) async {
      final parts = params.split(',');
      final page = int.tryParse(parts[0]) ?? 1;
      final pageSize = parts.length > 1 ? (int.tryParse(parts[1]) ?? 20) : 20;
      final repo = ref.watch(sessionRepositoryProvider);
      return await repo.getSessions(page: page, pageSize: pageSize);
    });

class SessionListScreen extends ConsumerStatefulWidget {
  const SessionListScreen({super.key});

  @override
  ConsumerState<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends ConsumerState<SessionListScreen> {
  int _currentPage = 1;
  final int _pageSize = 20;
  String _filterStatus = 'ALL'; // ALL, ACTIVE, COMPLETED

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(
      sessionsProvider('$_currentPage,$_pageSize'),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SESSION ARCHIVE',
          style: AppTypography.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.pureWhite : AppColors.carbon,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? AppColors.softSand : AppColors.warmGraphite,
            ),
            tooltip: 'Sync Archive',
            onPressed: () => _refreshSessions(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: NaadyantraAnimatedBackground(
        kind: NaadyantraBackgroundKind.sessions,
        lightScrimOpacity: 0.58,
        darkScrimOpacity: 0.50,
        child: Column(
          children: [
            // Filter Tabs Bar with Animated Smooth Selection
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xCC181716)
                    : AppColors.pureWhite.withValues(alpha: 0.95),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF2E2C29)
                        : AppColors.warmStone,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All Sessions'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ACTIVE', 'In Progress'),
                  const SizedBox(width: 8),
                  _buildFilterChip('COMPLETED', 'Completed'),
                ],
              ),
            ),

            // Main Session Content Area
            Expanded(
              child: sessionsAsync.when(
                data: (paginatedResponse) {
                  var items = paginatedResponse.items;
                  if (_filterStatus == 'ACTIVE') {
                    items = items.where((s) => s.isActive).toList();
                  } else if (_filterStatus == 'COMPLETED') {
                    items = items.where((s) => !s.isActive).toList();
                  }

                  if (items.isEmpty) {
                    return IndustrialEmptyView(
                      icon: Icons.history_rounded,
                      title: 'No Sessions Found',
                      message: _filterStatus == 'ALL'
                          ? 'Trigger a physical inspection run to archive telemetry.'
                          : 'No sessions matching filter $_filterStatus.',
                      actionLabel: 'Refresh Archive',
                      onAction: _refreshSessions,
                    );
                  }

                  final isCached = paginatedResponse.isFromCache;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: items.length + (isCached ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (isCached && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.darkSurfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.darkBorder),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.cloud_off_rounded,
                                  size: 16,
                                  color: AppColors.warmGraphite,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'OFFLINE BUFFER — DISPLAYING PERSISTED SQLITE CACHE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: AppColors.warmGraphite,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final actualIndex = isCached ? index - 1 : index;
                      final session = items[actualIndex];
                      return StaggeredEntrance(
                        index: actualIndex,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TactilePressable(
                            onTap: () => _navigateToSessionDetail(session),
                            child: _buildSessionCard(context, session),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const IndustrialLoadingView(
                  message: 'Loading telemetry archive...',
                ),
                error: (error, _) => IndustrialErrorView(
                  title: 'Archive Retrieval Error',
                  message: error.toString(),
                  onRetry: _refreshSessions,
                ),
              ),
            ),

            // Pagination Footer Bar
            sessionsAsync.maybeWhen(
              data: (response) {
                if (response.total <= _pageSize) return const SizedBox.shrink();
                return _buildPagination(context, response);
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterStatus == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _filterStatus = value;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: MotionTokens.durationFast,
        curve: MotionTokens.curveDecelerate,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.burntOrange
              : isDark
              ? AppColors.darkSurfaceElevated
              : AppColors.industrialIvory,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.burntOrange
                : isDark
                ? AppColors.darkBorder
                : AppColors.warmStone,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.burntOrange.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.pureWhite
                : isDark
                ? AppColors.darkTextSecondary
                : AppColors.carbon,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, Session session) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IndustrialCard(
      title: 'SESSION #${session.sessionId}',
      subtitle: DateFormat('yyyy-MM-dd • HH:mm:ss').format(session.startedAt),
      trailing: StatusPill(
        label: session.isActive ? 'ACTIVE' : 'COMPLETED',
        type: session.isActive ? StatusType.active : StatusType.completed,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildDataPill(
                icon: Icons.memory_rounded,
                label: 'Probe: ${session.deviceId}',
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildDataPill(
                icon: Icons.person_outline_rounded,
                label: 'Trainee: ${session.traineeId}',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                session.isActive
                    ? 'Status: Streaming telemetry…'
                    : 'Session Finalized',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: session.isActive
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: session.isActive
                      ? AppColors.alertWarning
                      : AppColors.warmGraphite,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Row(
                children: [
                  Text(
                    'View Diagnostics',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.burntOrange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.burntOrange,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataPill({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.industrialIvory,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.warmStone,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.warmGraphite),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(
    BuildContext context,
    PaginatedResponse<Session> response,
  ) {
    final totalPages = (response.total / _pageSize).ceil();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.pureWhite,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkBorder
                : AppColors.warmStone,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page $_currentPage of $totalPages (${response.total} runs)',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.warmGraphite,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToSessionDetail(Session session) {
    context.push('/sessions/${session.sessionId}');
  }

  void _refreshSessions() {
    ref.invalidate(sessionsProvider('$_currentPage,$_pageSize'));
  }
}
