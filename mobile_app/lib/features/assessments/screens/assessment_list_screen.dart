import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion_tokens.dart';
import '../../../shared/models/assessment.dart';
import '../../../shared/models/common.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/industrial_card.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/motion/tactile_pressable.dart';
import '../../../shared/backgrounds/naadyantra_animated_background.dart';

final assessmentsProvider =
    FutureProvider.autoDispose<PaginatedResponse<Assessment>>((ref) async {
      final repo = ref.watch(assessmentRepositoryProvider);
      return await repo.getAssessments();
    });

class AssessmentListScreen extends ConsumerWidget {
  const AssessmentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentsAsync = ref.watch(assessmentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VOCATIONAL EVALUATIONS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Sync Assessments',
            onPressed: () => ref.invalidate(assessmentsProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: NaadyantraAnimatedBackground(
        kind: NaadyantraBackgroundKind.assessments,
        lightScrimOpacity: 0.88,
        darkScrimOpacity: 0.70,
        child: assessmentsAsync.when(
          data: (paginatedResponse) {
            final items = paginatedResponse.items;
            if (items.isEmpty) {
              return IndustrialEmptyView(
                icon: Icons.assignment_turned_in_outlined,
                title: 'No Assessments On Record',
                message: 'Vocational evaluation rubrics will appear here once submitted by a certified trainer.',
                actionLabel: 'Check for Records',
                onAction: () => ref.invalidate(assessmentsProvider),
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Metric Summary Card
                StaggeredEntrance(
                  index: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.pureWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.warmStone,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
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
                                '${items.length} EVALUATIONS ARCHIVED',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.warmGraphite,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Pipeline Leak & Valve Inspection Competency',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Assessment Rubric Cards
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final assessment = entry.value;

                  return StaggeredEntrance(
                    index: index + 1,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TactilePressable(
                        onTap: () => context.push(
                          '/assessments/${assessment.assessmentId}',
                        ),
                        child: _buildAssessmentCard(
                          context,
                          assessment,
                          isDark,
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],
            );
          },
          loading: () => const IndustrialLoadingView(
            message: 'Loading trainee evaluation rubrics...',
          ),
          error: (error, _) => IndustrialErrorView(
            title: 'Assessments Unavailable',
            message: error.toString(),
            onRetry: () => ref.invalidate(assessmentsProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentCard(
    BuildContext context,
    Assessment assessment,
    bool isDark,
  ) {
    final score = assessment.score ?? 0.0;
    final maxScore = (assessment.maxScore != null && assessment.maxScore! > 0)
        ? assessment.maxScore!
        : 100.0;
    final percentage = (score / maxScore).clamp(0.0, 1.0);
    final isPassing = percentage >= 0.7;
    final isReduced = MotionTokens.isReducedMotion(context);

    return IndustrialCard(
      title: 'TRAINEE #${assessment.traineeId}',
      subtitle: 'Session ID: ${assessment.sessionId}',
      trailing: StatusPill(
        label: isPassing ? 'COMPETENT' : 'NEEDS TRAINING',
        type: isPassing ? StatusType.completed : StatusType.caution,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Skill Competency Score',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.warmGraphite,
                ),
              ),
              Text(
                '${score.toStringAsFixed(0)} / ${maxScore.toStringAsFixed(0)} pts (${(percentage * 100).toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isPassing ? AppColors.alertOk : AppColors.alertCaution,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: isReduced
                ? LinearProgressIndicator(
                    value: percentage,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.warmStone.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPassing ? AppColors.alertOk : AppColors.alertCaution,
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: percentage),
                    duration: MotionTokens.durationSlow,
                    curve: MotionTokens.curveDecelerate,
                    builder: (context, val, child) {
                      return LinearProgressIndicator(
                        value: val,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.warmStone.withValues(alpha: 0.5),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isPassing
                              ? AppColors.alertOk
                              : AppColors.alertCaution,
                        ),
                      );
                    },
                  ),
          ),
          if (assessment.scoringExplanation != null &&
              assessment.scoringExplanation!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.comment_outlined,
                    size: 14,
                    color: AppColors.warmGraphite,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      assessment.scoringExplanation!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.warmGraphite,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
