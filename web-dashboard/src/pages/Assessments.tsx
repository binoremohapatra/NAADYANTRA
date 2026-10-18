import { useState, useEffect, useCallback } from 'react';
import { apiClient } from '../api/client';
import { useDemo } from '../context/DemoContext';
import type { Assessment, AssessmentRubric, PaginatedResponse } from '../types';

export default function Assessments() {
  const { isDemoMode, demoData } = useDemo();

  const [assessments, setAssessments] = useState<PaginatedResponse<Assessment> | null>(null);
  const [rubrics, setRubrics] = useState<AssessmentRubric[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');
  const [traineeFilter, setTraineeFilter] = useState<string>('');
  const [outcomeFilter, setOutcomeFilter] = useState<string>('');
  const [page, setPage] = useState<number>(1);
  const [activeTab, setActiveTab] = useState<'evaluations' | 'rubrics'>('evaluations');

  // Review Modal
  const [selectedAssessment, setSelectedAssessment] = useState<Assessment | null>(null);
  const [reviewComments, setReviewComments] = useState<string>('');
  const [overrideScore, setOverrideScore] = useState<string>('');
  const [overrideOutcome, setOverrideOutcome] = useState<string>('');
  const [isSubmittingReview, setIsSubmittingReview] = useState<boolean>(false);
  const [reviewError, setReviewError] = useState<string>('');
  const [reviewSuccess, setReviewSuccess] = useState<string>('');

  // Create Assessment Modal
  const [isCreateModalOpen, setIsCreateModalOpen] = useState<boolean>(false);
  const [newAssessmentId, setNewAssessmentId] = useState<string>('');
  const [newSessionId, setNewSessionId] = useState<string>('');
  const [newRubricId, setNewRubricId] = useState<string>('RUBRIC-LEAK-V1');
  const [newRubricVersion, setNewRubricVersion] = useState<string>('1.0');
  const [newEvidenceIds, setNewEvidenceIds] = useState<string>('');
  const [newScoringExplanation, setNewScoringExplanation] = useState<string>('');
  const [isSubmittingNew, setIsSubmittingNew] = useState<boolean>(false);
  const [createError, setCreateError] = useState<string>('');

  const loadAssessments = useCallback(async () => {
    try {
      setIsLoading(true);
      setError('');

      if (isDemoMode) {
        let items = [...demoData.assessments];
        if (traineeFilter.trim()) {
          items = items.filter((a) => a.trainee_id.toLowerCase().includes(traineeFilter.trim().toLowerCase()));
        }
        if (outcomeFilter.trim()) {
          items = items.filter((a) => a.outcome.toLowerCase() === outcomeFilter.trim().toLowerCase());
        }
        setAssessments({
          total: items.length,
          page,
          page_size: 25,
          items,
        });
        setIsLoading(false);
        return;
      }

      const params: any = { page, page_size: 25 };
      if (traineeFilter.trim()) params.trainee_id = traineeFilter.trim();
      if (outcomeFilter.trim()) params.outcome = outcomeFilter.trim();
      const res = await apiClient.getAssessments(params);
      setAssessments(res);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load assessments');
    } finally {
      setIsLoading(false);
    }
  }, [isDemoMode, demoData.assessments, page, traineeFilter, outcomeFilter]);

  const loadRubrics = useCallback(async () => {
    try {
      if (isDemoMode) {
        setRubrics(demoData.rubrics);
        return;
      }
      const res = await apiClient.getRubrics({ page: 1, page_size: 50 });
      setRubrics(res.items);
    } catch (err) {
      console.error('Failed to load rubrics', err);
      setRubrics(demoData.rubrics);
    }
  }, [isDemoMode, demoData.rubrics]);

  useEffect(() => {
    loadAssessments();
    loadRubrics();
  }, [loadAssessments, loadRubrics]);

  const handleOpenReview = (a: Assessment) => {
    setSelectedAssessment(a);
    setReviewComments('');
    setOverrideScore(a.score !== null ? String(a.score) : '');
    setOverrideOutcome(a.outcome);
    setReviewError('');
    setReviewSuccess('');
  };

  const handleSubmitReview = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedAssessment) return;
    if (!reviewComments.trim()) {
      setReviewError('Trainer review comments are required');
      return;
    }
    try {
      setIsSubmittingReview(true);
      setReviewError('');
      setReviewSuccess('');

      if (!isDemoMode) {
        await apiClient.reviewAssessment(selectedAssessment.assessment_id, {
          comments: reviewComments.trim(),
          override_score: overrideScore !== '' ? Number(overrideScore) : undefined,
          override_outcome: overrideOutcome || undefined,
        });
      }

      setReviewSuccess('Trainer review logged and assessment record updated.');
      await loadAssessments();
      setTimeout(() => setSelectedAssessment(null), 1200);
    } catch (err: any) {
      setReviewError(err.response?.data?.detail || 'Failed to submit trainer review');
    } finally {
      setIsSubmittingReview(false);
    }
  };

  const handleCreateAssessment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAssessmentId.trim() || !newSessionId.trim() || !newRubricId.trim()) {
      setCreateError('Assessment ID, Session ID, and Rubric are required');
      return;
    }
    const evidenceList = newEvidenceIds
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s.length > 0)
      .map((s) => Number(s))
      .filter((n) => !isNaN(n));

    try {
      setIsSubmittingNew(true);
      setCreateError('');

      if (!isDemoMode) {
        await apiClient.createAssessment({
          assessment_id: newAssessmentId.trim().toUpperCase(),
          session_id: Number(newSessionId),
          rubric_id: newRubricId.trim(),
          rubric_version: newRubricVersion.trim() || '1.0',
          evidence_event_ids: evidenceList,
          scoring_explanation: newScoringExplanation.trim() || undefined,
        });
      }

      setIsCreateModalOpen(false);
      setNewAssessmentId('');
      setNewSessionId('');
      setNewEvidenceIds('');
      setNewScoringExplanation('');
      await loadAssessments();
    } catch (err: any) {
      setCreateError(err.response?.data?.detail || 'Failed to initialize assessment');
    } finally {
      setIsSubmittingNew(false);
    }
  };

  const outcomeBadge = (outcome: string) => {
    switch (outcome?.toLowerCase()) {
      case 'competent':
        return <span className="hg-badge hg-badge-ok">✓ Competent</span>;
      case 'needs_improvement':
        return <span className="hg-badge hg-badge-caution">⚠ Needs Improvement</span>;
      case 'not_assessable':
        return <span className="hg-badge hg-badge-danger">✕ Not Assessable</span>;
      default:
        return <span className="hg-badge hg-badge-neutral">{outcome || 'Pending'}</span>;
    }
  };

  return (
    <div>
      {/* Page Header */}
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">NSQF Skill Assessments &amp; Rubrics</h1>
          <p className="hg-page-subtitle">
            Vocational candidate evaluation, objective rubric criteria &amp; trainer audit logging
          </p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button
            className="hg-btn hg-btn-primary"
            onClick={() => {
              setNewAssessmentId(`ASM-${Date.now().toString().slice(-6)}`);
              setNewSessionId('');
              setNewEvidenceIds('');
              setNewScoringExplanation('');
              setCreateError('');
              setIsCreateModalOpen(true);
            }}
          >
            + New Assessment
          </button>
        </div>
      </div>

      {/* Accreditation Notice */}
      <div
        style={{
          background: 'var(--color-ivory)',
          border: '1px solid var(--color-warm-stone)',
          borderRadius: 8,
          padding: '12px 16px',
          marginBottom: 20,
          display: 'flex',
          gap: 12,
          alignItems: 'flex-start',
        }}
      >
        <span style={{ fontSize: 16 }}>📜</span>
        <div style={{ fontSize: 12, lineHeight: 1.5, color: 'var(--color-carbon)' }}>
          <strong style={{ color: 'var(--color-dark-burnt-orange)' }}>
            Regulatory Framework &amp; Model Provenance Declaration:
          </strong>
          <span style={{ color: 'var(--color-warm-graphite)', display: 'block', marginTop: 2 }}>
            • <strong>Curriculum Alignment</strong>: Assesses competencies against National Qualifications Register (NQR) standards: <code>PSC/Q0104</code> (Plumber Level 4), <code>ELE/Q3102</code> (AC Tech Level 4), and <code>CSC/Q0901</code> (Fitter Level 3).
            <br />
            • <strong>Accreditation Status</strong>: NAADYANTRA is an educational vocational tool; official certification requires an authorized awarding body (NCVET/DGT/SSC).
            <br />
            • <strong>Signal Model Notice</strong>: Active acoustic detection operates via deterministic RMS threshold ratio <code>(rms)</code> rather than an empirically validated neural network.
          </span>
        </div>
      </div>

      {/* Tab Navigation */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        <button
          className={`hg-btn ${activeTab === 'evaluations' ? 'hg-btn-primary' : 'hg-btn-secondary'}`}
          onClick={() => setActiveTab('evaluations')}
        >
          Candidate Evaluations ({assessments?.total ?? 0})
        </button>
        <button
          className={`hg-btn ${activeTab === 'rubrics' ? 'hg-btn-primary' : 'hg-btn-secondary'}`}
          onClick={() => setActiveTab('rubrics')}
        >
          Standardized Rubrics ({rubrics.length})
        </button>
      </div>

      {/* TAB 1: EVALUATIONS */}
      {activeTab === 'evaluations' && (
        <>
          {/* Filters Bar */}
          <div className="hg-filters" style={{ background: 'var(--color-white)', padding: 14, borderRadius: 8, border: '1px solid var(--color-warm-stone)', marginBottom: 20 }}>
            <div style={{ minWidth: 200 }}>
              <label className="hg-label">Candidate Trainee ID</label>
              <input
                type="text"
                className="hg-input"
                placeholder="Filter by Trainee ID (e.g. T001)..."
                value={traineeFilter}
                onChange={(e) => {
                  setTraineeFilter(e.target.value);
                  setPage(1);
                }}
              />
            </div>

            <div style={{ minWidth: 160 }}>
              <label className="hg-label">Outcome Status</label>
              <select
                className="hg-input"
                value={outcomeFilter}
                onChange={(e) => {
                  setOutcomeFilter(e.target.value);
                  setPage(1);
                }}
              >
                <option value="">All Outcomes</option>
                <option value="competent">Competent (Passing)</option>
                <option value="needs_improvement">Needs Improvement</option>
                <option value="not_assessable">Not Assessable</option>
              </select>
            </div>

            {(traineeFilter || outcomeFilter) && (
              <div style={{ display: 'flex', alignItems: 'flex-end' }}>
                <button
                  className="hg-btn hg-btn-ghost"
                  onClick={() => {
                    setTraineeFilter('');
                    setOutcomeFilter('');
                    setPage(1);
                  }}
                  style={{ fontSize: 12 }}
                >
                  Clear Filters
                </button>
              </div>
            )}
          </div>

          {/* Evaluations Table */}
          <div className="hg-card" style={{ padding: 0, overflow: 'hidden' }}>
            {isLoading ? (
              <div className="hg-loading-screen" style={{ padding: 40 }}>
                <div className="hg-spinner" />
                <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>Loading candidate assessments…</span>
              </div>
            ) : error ? (
              <div style={{ padding: 24, color: 'var(--color-alert-danger)' }}>{error}</div>
            ) : !assessments || assessments.items.length === 0 ? (
              <div className="hg-empty" style={{ padding: 48 }}>
                <div className="hg-empty-icon">📋</div>
                <p className="hg-empty-title">No Assessment Records Found</p>
                <p className="hg-empty-desc">Initialize an assessment after a candidate diagnostic session.</p>
              </div>
            ) : (
              <div style={{ overflowX: 'auto' }}>
                <table className="hg-table">
                  <thead>
                    <tr>
                      <th>Assessment ID</th>
                      <th>Candidate</th>
                      <th>Session ID</th>
                      <th>Rubric / Standard</th>
                      <th>Score</th>
                      <th>Outcome</th>
                      <th>Assessor</th>
                      <th>Date</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {assessments.items.map((a) => (
                      <tr key={a.id}>
                        <td>
                          <span className="hg-code">{a.assessment_id}</span>
                        </td>
                        <td>
                          <strong>{a.trainee_id}</strong>
                        </td>
                        <td>
                          <span className="hg-code">#{a.session_id}</span>
                        </td>
                        <td>
                          <span style={{ fontWeight: 600, color: 'var(--color-carbon)' }}>{a.rubric_id}</span>
                          <span style={{ display: 'block', fontSize: 11, color: 'var(--color-warm-graphite)' }}>v{a.rubric_version}</span>
                        </td>
                        <td style={{ fontFamily: 'var(--font-mono)' }}>
                          {a.score !== null ? (
                            <strong style={{ color: a.score >= 75 ? 'var(--color-alert-ok)' : 'var(--color-alert-caution)' }}>
                              {a.score} / {a.max_score ?? 100}
                            </strong>
                          ) : (
                            <span style={{ color: 'var(--color-warm-graphite)' }}>Pending</span>
                          )}
                        </td>
                        <td>{outcomeBadge(a.outcome)}</td>
                        <td style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>{a.created_by}</td>
                        <td style={{ fontSize: 12, color: 'var(--color-warm-graphite)', whiteSpace: 'nowrap' }}>
                          {new Date(a.created_at).toLocaleDateString()}
                        </td>
                        <td>
                          <button
                            className="hg-btn hg-btn-secondary"
                            style={{ padding: '4px 10px', fontSize: 11 }}
                            onClick={() => handleOpenReview(a)}
                          >
                            Review &amp; Override
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}

      {/* TAB 2: STANDARDIZED RUBRICS */}
      {activeTab === 'rubrics' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))', gap: 20 }}>
          {rubrics.map((r) => {
            const rules = r.rules || {};
            const criteria = rules.criteria || [];
            return (
              <div key={r.id} className="hg-card">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
                  <div>
                    <span className="hg-code">{r.rubric_id} v{r.version}</span>
                    <h3 style={{ fontSize: 16, margin: '6px 0 2px', color: 'var(--color-carbon)' }}>{r.name}</h3>
                  </div>
                  <span className="hg-badge hg-badge-ok">ACTIVE</span>
                </div>

                <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', lineHeight: 1.5, marginBottom: 16 }}>
                  {r.description}
                </p>

                <div style={{ background: 'var(--color-ivory)', padding: 12, borderRadius: 6, border: '1px solid var(--color-warm-stone)', marginBottom: 16 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12 }}>
                    <span>Trade Scope: <strong>{rules.trade_alignment || 'Vocational Piping'}</strong></span>
                    <span>Pass Score: <strong>{rules.passing_score ?? 75}%</strong></span>
                  </div>
                </div>

                <div style={{ fontSize: 12, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)', marginBottom: 8 }}>
                  Criteria Breakdown:
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                  {criteria.map((c: any, i: number) => (
                    <div key={i} style={{ background: 'var(--color-white)', border: '1px solid var(--color-warm-stone)', padding: 10, borderRadius: 6 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <strong style={{ fontSize: 12, color: 'var(--color-carbon)' }}>{c.code}: {c.title}</strong>
                        <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--color-dark-burnt-orange)' }}>{c.weight} pts</span>
                      </div>
                      <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', marginTop: 2 }}>{c.rule}</div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Trainer Review & Override Modal */}
      {selectedAssessment && (
        <div className="hg-modal-backdrop" onClick={() => setSelectedAssessment(null)}>
          <div className="hg-modal" style={{ maxWidth: 540 }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <div>
                <h3 style={{ fontSize: 16, margin: 0 }}>Trainer Assessment Review</h3>
                <span style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
                  Record: <strong>{selectedAssessment.assessment_id}</strong> · Candidate: <strong>{selectedAssessment.trainee_id}</strong>
                </span>
              </div>
              <button className="hg-close-btn" onClick={() => setSelectedAssessment(null)}>×</button>
            </div>

            {selectedAssessment.scoring_explanation && (
              <div style={{ background: 'var(--color-ivory)', padding: 12, borderRadius: 6, border: '1px solid var(--color-warm-stone)', fontSize: 12, color: 'var(--color-carbon)', marginBottom: 16 }}>
                <strong>Evidence Summary:</strong>
                <p style={{ margin: '4px 0 0', color: 'var(--color-warm-graphite)', lineHeight: 1.4 }}>
                  {selectedAssessment.scoring_explanation}
                </p>
              </div>
            )}

            <form onSubmit={handleSubmitReview}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 14 }}>
                <div>
                  <label className="hg-label">Override Score (0-100)</label>
                  <input
                    type="number"
                    className="hg-input"
                    placeholder="e.g. 85"
                    value={overrideScore}
                    onChange={(e) => setOverrideScore(e.target.value)}
                    min="0"
                    max="100"
                  />
                </div>
                <div>
                  <label className="hg-label">Override Outcome</label>
                  <select
                    className="hg-input"
                    value={overrideOutcome}
                    onChange={(e) => setOverrideOutcome(e.target.value)}
                  >
                    <option value="competent">Competent</option>
                    <option value="needs_improvement">Needs Improvement</option>
                    <option value="not_assessable">Not Assessable</option>
                  </select>
                </div>
              </div>

              <div style={{ marginBottom: 16 }}>
                <label className="hg-label">Trainer Review Remarks (Required)</label>
                <textarea
                  className="hg-input"
                  rows={3}
                  placeholder="Enter qualitative justification for score or procedure verification..."
                  value={reviewComments}
                  onChange={(e) => setReviewComments(e.target.value)}
                  required
                />
              </div>

              {reviewError && <div className="hg-alert hg-alert-error" style={{ marginBottom: 12 }}>{reviewError}</div>}
              {reviewSuccess && <div className="hg-alert hg-alert-success" style={{ marginBottom: 12 }}>{reviewSuccess}</div>}

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
                <button type="button" className="hg-btn hg-btn-secondary" onClick={() => setSelectedAssessment(null)}>
                  Cancel
                </button>
                <button type="submit" className="hg-btn hg-btn-primary" disabled={isSubmittingReview}>
                  {isSubmittingReview ? 'Logging Review…' : 'Save Review & Audit Entry'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Create Assessment Modal */}
      {isCreateModalOpen && (
        <div className="hg-modal-backdrop" onClick={() => setIsCreateModalOpen(false)}>
          <div className="hg-modal" style={{ maxWidth: 540 }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h3 style={{ fontSize: 16, margin: 0 }}>Initialize New Skill Assessment</h3>
              <button className="hg-close-btn" onClick={() => setIsCreateModalOpen(false)}>×</button>
            </div>

            <form onSubmit={handleCreateAssessment}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
                <div>
                  <label className="hg-label">Assessment ID</label>
                  <input
                    type="text"
                    className="hg-input"
                    value={newAssessmentId}
                    onChange={(e) => setNewAssessmentId(e.target.value)}
                    required
                  />
                </div>
                <div>
                  <label className="hg-label">Session ID</label>
                  <input
                    type="number"
                    className="hg-input"
                    placeholder="e.g. 101"
                    value={newSessionId}
                    onChange={(e) => setNewSessionId(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
                <div>
                  <label className="hg-label">Rubric ID</label>
                  <select
                    className="hg-input"
                    value={newRubricId}
                    onChange={(e) => setNewRubricId(e.target.value)}
                  >
                    <option value="RUBRIC-LEAK-V1">RUBRIC-LEAK-V1 (Acoustic)</option>
                    <option value="RUBRIC-HAZARD-V1">RUBRIC-HAZARD-V1 (Multi-Hazard)</option>
                  </select>
                </div>
                <div>
                  <label className="hg-label">Rubric Version</label>
                  <input
                    type="text"
                    className="hg-input"
                    value={newRubricVersion}
                    onChange={(e) => setNewRubricVersion(e.target.value)}
                  />
                </div>
              </div>

              <div style={{ marginBottom: 12 }}>
                <label className="hg-label">Evidence Event IDs (comma-separated)</label>
                <input
                  type="text"
                  className="hg-input"
                  placeholder="e.g. 9001, 9002, 9003"
                  value={newEvidenceIds}
                  onChange={(e) => setNewEvidenceIds(e.target.value)}
                />
              </div>

              <div style={{ marginBottom: 16 }}>
                <label className="hg-label">Preliminary Scoring Explanation</label>
                <textarea
                  className="hg-input"
                  rows={2}
                  placeholder="Rationale or observations during candidate testing..."
                  value={newScoringExplanation}
                  onChange={(e) => setNewScoringExplanation(e.target.value)}
                />
              </div>

              {createError && <div className="hg-alert hg-alert-error" style={{ marginBottom: 12 }}>{createError}</div>}

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
                <button type="button" className="hg-btn hg-btn-secondary" onClick={() => setIsCreateModalOpen(false)}>
                  Cancel
                </button>
                <button type="submit" className="hg-btn hg-btn-primary" disabled={isSubmittingNew}>
                  {isSubmittingNew ? 'Creating…' : 'Create Assessment Record'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
