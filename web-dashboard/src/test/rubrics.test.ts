import { describe, it, expect } from 'vitest';

interface CriteriaScore {
  criteriaId: string;
  weight: number;
  awardedScore: number;
}

function evaluateCandidateCompetency(
  scores: CriteriaScore[],
  passingPercentage = 75.0,
  minDurationSec = 30,
  actualDurationSec = 45,
  hasSensorFault = false
): { totalScore: number; percentage: number; outcome: 'COMPETENT' | 'NEEDS_IMPROVEMENT' | 'NOT_ASSESSABLE' } {
  if (hasSensorFault || actualDurationSec < 15) {
    return { totalScore: 0, percentage: 0, outcome: 'NOT_ASSESSABLE' };
  }

  const totalPossible = scores.reduce((acc, c) => acc + c.weight, 0);
  const totalAwarded = scores.reduce((acc, c) => acc + c.awardedScore, 0);
  const percentage = (totalAwarded / totalPossible) * 100;

  if (actualDurationSec < minDurationSec || percentage < passingPercentage) {
    return { totalScore: totalAwarded, percentage, outcome: 'NEEDS_IMPROVEMENT' };
  }

  return { totalScore: totalAwarded, percentage, outcome: 'COMPETENT' };
}

describe('NSQF Rubric Architecture & Outcome Evaluation', () => {
  const rubricLeakV1 = [
    { criteriaId: 'CRIT-01', name: 'Baseline Ambient Calibration', weight: 20 },
    { criteriaId: 'CRIT-02', name: 'Probe Coupling & Signal Integrity', weight: 30 },
    { criteriaId: 'CRIT-03', name: 'Leak Identification & Triage', weight: 35 },
    { criteriaId: 'CRIT-04', name: 'Inspection Hygiene & Closure', weight: 15 },
  ];

  it('verifies RUBRIC-LEAK-V1 weights sum exactly to 100 points', () => {
    const totalWeight = rubricLeakV1.reduce((sum, item) => sum + item.weight, 0);
    expect(totalWeight).toBe(100);
  });

  it('evaluates candidate as COMPETENT when score >= 75% and protocol satisfied', () => {
    const scores: CriteriaScore[] = [
      { criteriaId: 'CRIT-01', weight: 20, awardedScore: 18 },
      { criteriaId: 'CRIT-02', weight: 30, awardedScore: 26 },
      { criteriaId: 'CRIT-03', weight: 35, awardedScore: 30 },
      { criteriaId: 'CRIT-04', weight: 15, awardedScore: 14 },
    ];

    const result = evaluateCandidateCompetency(scores, 75.0, 30, 48, false);
    expect(result.totalScore).toBe(88);
    expect(result.percentage).toBe(88);
    expect(result.outcome).toBe('COMPETENT');
  });

  it('evaluates candidate as NEEDS_IMPROVEMENT when score < 75%', () => {
    const scores: CriteriaScore[] = [
      { criteriaId: 'CRIT-01', weight: 20, awardedScore: 10 },
      { criteriaId: 'CRIT-02', weight: 30, awardedScore: 15 },
      { criteriaId: 'CRIT-03', weight: 35, awardedScore: 20 },
      { criteriaId: 'CRIT-04', weight: 15, awardedScore: 10 },
    ];

    const result = evaluateCandidateCompetency(scores, 75.0, 30, 40, false);
    expect(result.totalScore).toBe(55);
    expect(result.percentage).toBeCloseTo(55);
    expect(result.outcome).toBe('NEEDS_IMPROVEMENT');
  });

  it('evaluates as NOT_ASSESSABLE if hardware sensor fault detected or aborted under 15s', () => {
    const scores: CriteriaScore[] = [
      { criteriaId: 'CRIT-01', weight: 20, awardedScore: 20 },
      { criteriaId: 'CRIT-02', weight: 30, awardedScore: 30 },
      { criteriaId: 'CRIT-03', weight: 35, awardedScore: 35 },
      { criteriaId: 'CRIT-04', weight: 15, awardedScore: 15 },
    ];

    const faulted = evaluateCandidateCompetency(scores, 75.0, 30, 45, true);
    expect(faulted.outcome).toBe('NOT_ASSESSABLE');

    const aborted = evaluateCandidateCompetency(scores, 75.0, 30, 10, false);
    expect(aborted.outcome).toBe('NOT_ASSESSABLE');
  });
});
