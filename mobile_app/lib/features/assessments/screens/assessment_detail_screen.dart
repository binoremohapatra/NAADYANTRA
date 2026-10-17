import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion_tokens.dart';
import '../../../shared/models/assessment.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/industrial_card.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/backgrounds/naadyantra_animated_background.dart';

final assessmentDetailProvider = FutureProvider.autoDispose
    .family<Assessment, String>((ref, assessmentId) async {
      final repo = ref.watch(assessmentRepositoryProvider);
      return repo.getAssessment(assessmentId);
    });

class AssessmentDetailScreen extends ConsumerWidget {
  final String assessmentId;

  const AssessmentDetailScreen({super.key, required this.assessmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentAsync = ref.watch(assessmentDetailProvider(assessmentId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('EVALUATION #${assessmentId.toUpperCase()}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload Assessment',
            onPressed: () =>
                ref.invalidate(assessmentDetailProvider(assessmentId)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: NaadyantraAnimatedBackground(
        kind: NaadyantraBackgroundKind.assessmentDetails,
        lightScrimOpacity: 0.88,
        darkScrimOpacity: 0.70,
        child: assessmentAsync.when(
          data: (assessment) =>
              _AssessmentDetailBody(assessment: assessment, isDark: isDark),
          loading: () => const IndustrialLoadingView(
            message: 'Loading assessment record...',
          ),
          error: (err, _) => IndustrialErrorView(
            title: 'Assessment Not Found',
            message: err.toString(),
            onRetry: () =>
                ref.invalidate(assessmentDetailProvider(assessmentId)),
          ),
        ),
      ),
    );
  }
}

class _AssessmentDetailBody extends StatelessWidget {
  final Assessment assessment;
  final bool isDark;

  const _AssessmentDetailBody({required this.assessment, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final score = assessment.score ?? 0.0;
    final maxScore = (assessment.maxScore != null && assessment.maxScore! > 0)
        ? assessment.maxScore!
        : 100.0;
    final percentage = (score / maxScore).clamp(0.0, 1.0);
    final isPassing = percentage >= 0.7;
    final isReduced = MotionTokens.isReducedMotion(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ── Outcome Header Card ──
        StaggeredEntrance(
          index: 0,
          child: IndustrialCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPassing
                            ? AppColors.alertOk.withValues(alpha: 0.1)
                            : AppColors.alertCaution.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPassing
                            ? Icons.workspace_premium_rounded
                            : Icons.school_rounded,
                        color: isPassing
                            ? AppColors.alertOk
                            : AppColors.alertCaution,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trainee: ${assessment.traineeId}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rubric: ${assessment.rubricId} v${assessment.rubricVersion}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.warmGraphite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      label: isPassing ? 'COMPETENT' : 'NEEDS TRAINING',
                      type: isPassing ? StatusType.ok : StatusType.caution,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Score Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Competency Score',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.warmGraphite,
                      ),
                    ),
                    Text(
                      '${score.toStringAsFixed(0)} / ${maxScore.toStringAsFixed(0)} pts '
                      '(${(percentage * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isPassing
                            ? AppColors.alertOk
                            : AppColors.alertCaution,
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
                          minHeight: 8,
                          backgroundColor: isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.warmStone.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isPassing
                                ? AppColors.alertOk
                                : AppColors.alertCaution,
                          ),
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: percentage),
                          duration: MotionTokens.durationSlow,
                          curve: MotionTokens.curveDecelerate,
                          builder: (context, val, _) => LinearProgressIndicator(
                            value: val,
                            minHeight: 8,
                            backgroundColor: isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.warmStone.withValues(alpha: 0.5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isPassing
                                  ? AppColors.alertOk
                                  : AppColors.alertCaution,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Session Linkage ──
        StaggeredEntrance(
          index: 1,
          child: IndustrialCard(
            title: 'LINKED SESSION',
            child: _buildInfoRow(
              context,
              label: 'Session ID',
              value: '#${assessment.sessionId}',
              isDark: isDark,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Scoring Explanation ──
        if (assessment.scoringExplanation != null &&
            assessment.scoringExplanation!.isNotEmpty)
          StaggeredEntrance(
            index: 2,
            child: IndustrialCard(
              title: 'TRAINER NOTES',
              child: Container(
                padding: const EdgeInsets.all(12),
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
                      size: 16,
                      color: AppColors.warmGraphite,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        assessment.scoringExplanation!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.warmGraphite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // ── Evidence Events ──
        if (assessment.evidenceEventIds.isNotEmpty)
          StaggeredEntrance(
            index: 3,
            child: IndustrialCard(
              title: 'EVIDENCE EVENTS',
              subtitle:
                  '${assessment.evidenceEventIds.length} telemetry event(s) linked',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: assessment.evidenceEventIds.map((id) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.industrialIvory,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.warmStone,
                      ),
                    ),
                    child: Text(
                      'EVT #$id',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: AppColors.warmGraphite,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // ── Metadata ──
        StaggeredEntrance(
          index: 4,
          child: IndustrialCard(
            title: 'RECORD METADATA',
            child: Column(
              children: [
                _buildInfoRow(
                  context,
                  label: 'Assessment ID',
                  value: assessment.assessmentId,
                  isDark: isDark,
                ),
                const Divider(height: 1),
                _buildInfoRow(
                  context,
                  label: 'Created By',
                  value: assessment.createdBy,
                  isDark: isDark,
                ),
                const Divider(height: 1),
                _buildInfoRow(
                  context,
                  label: 'Created At',
                  value: DateFormat('yyyy-MM-dd HH:mm')
                      .format(assessment.createdAt.toLocal()),
                  isDark: isDark,
                ),
                const Divider(height: 1),
                _buildInfoRow(
                  context,
                  label: 'Outcome',
                  value: assessment.outcome,
                  isDark: isDark,
                  valueColor: isPassing
                      ? AppColors.alertOk
                      : AppColors.alertCaution,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Safety Notice ──
        StaggeredEntrance(
          index: 5,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warmStone.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warmStone),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.warmGraphite,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This assessment is a training aid only. Scores are model outputs and '
                    'should be reviewed by a certified trainer before any competency '
                    'determination.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.warmGraphite,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.warmGraphite,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color:
                    valueColor ??
                    (isDark ? AppColors.darkTextPrimary : AppColors.carbon),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
