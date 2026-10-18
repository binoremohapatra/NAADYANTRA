import { useState, useEffect } from 'react';
import { apiClient } from '../api/client';
import type { Assessment, AssessmentRubric, PaginatedResponse } from '../types';

export default function Assessments() {
  const [assessments, setAssessments] = useState<PaginatedResponse<Assessment> | null>(null);
  const [rubrics, setRubrics] = useState<AssessmentRubric[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [traineeFilter, setTraineeFilter] = useState('');
  const [outcomeFilter, setOutcomeFilter] = useState('');
  const [page, setPage] = useState(1);
  const [activeTab, setActiveTab] = useState<'evaluations' | 'rubrics'>('evaluations');

  // Review Modal
  const [selectedAssessment, setSelectedAssessment] = useState<Assessment | null>(null);
  const [reviewComments, setReviewComments] = useState('');
  const [overrideScore, setOverrideScore] = useState<string>('');
  const [overrideOutcome, setOverrideOutcome] = useState<string>('');
  const [isSubmittingReview, setIsSubmittingReview] = useState(false);
  const [reviewError, setReviewError] = useState('');
  const [reviewSuccess, setReviewSuccess] = useState('');

  // Create Assessment Modal
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [newAssessmentId, setNewAssessmentId] = useState('');
  const [newSessionId, setNewSessionId] = useState('');
  const [newRubricId, setNewRubricId] = useState('RUBRIC-LEAK-V1');
  const [newRubricVersion, setNewRubricVersion] = useState('1.0');
  const [newEvidenceIds, setNewEvidenceIds] = useState('');
  const [newScoringExplanation, setNewScoringExplanation] = useState('');
  const [isSubmittingNew, setIsSubmittingNew] = useState(false);
  const [createError, setCreateError] = useState('');

  useEffect(() => {
    loadAssessments();
    loadRubrics();
  }, [page, traineeFilter, outcomeFilter]);

  const loadAssessments = async () => {
    try {
      setIsLoading(true);
      setError('');
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
  };

  const loadRubrics = async () => {
    try {
      const res = await apiClient.getRubrics({ page: 1, page_size: 50 });
      setRubrics(res.items);
    } catch (err) {
      console.error('Failed to load rubrics', err);
    }
  };

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
      await apiClient.reviewAssessment(selectedAssessment.assessment_id, {
        comments: reviewComments.trim(),
        override_score: overrideScore !== '' ? Number(overrideScore) : undefined,
        override_outcome: overrideOutcome || undefined,
      });
      setReviewSuccess('Trainer review logged and assessment updated.');
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
      await apiClient.createAssessment({
        assessment_id: newAssessmentId.trim().toUpperCase(),
        session_id: Number(newSessionId),
        rubric_id: newRubricId.trim(),
        rubric_version: newRubricVersion.trim() || '1.0',
        evidence_event_ids: evidenceList,
        scoring_explanation: newScoringExplanation.trim() || undefined,
      });
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
        return <span className="hg-badge hg-badge-caution">△ Needs Improvement</span>;
      default:
        return <span className="hg-badge hg-badge-neutral">Not Assessable</span>;
    }
  };

  const totalPages = assessments ? Math.max(1, Math.ceil(assessments.total / 25)) : 1;

  return (
    <div>
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">Vocational Assessments</h1>
          <p className="hg-page-subtitle">
            Diagnostic session evaluations mapped to skilled trades competency rubrics
          </p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button className="hg-btn hg-btn-primary" onClick={() => setIsCreateModalOpen(true)}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M6.5 1v11M1 6.5h11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
            Create Evaluation
          </button>
          <button className="hg-btn hg-btn-secondary" onClick={() => { loadAssessments(); loadRubrics(); }}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
              <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            Refresh
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ marginBottom: 20 }}>
        <div className="hg-tabs">
          <button
            className={`hg-tab${activeTab === 'evaluations' ? ' active' : ''}`}
            onClick={() => setActiveTab('evaluations')}
          >
            Session Evaluations
          </button>
          <button
            className={`hg-tab${activeTab === 'rubrics' ? ' active' : ''}`}
            onClick={() => setActiveTab('rubrics')}
          >
            Competency Rubrics ({rubrics.length})
          </button>
        </div>
      </div>

      {activeTab === 'evaluations' && (
        <>
          {/* Filters */}
          <div className="hg-card" style={{ marginBottom: 20, padding: '16px 20px' }}>
            <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
              <div style={{ flex: 1, minWidth: 180 }}>
                <label className="hg-label">Trainee ID</label>
                <input
                  type="text"
                  className="hg-input"
                  placeholder="Filter by trainee ID…"
                  value={traineeFilter}
                  onChange={(e) => { setTraineeFilter(e.target.value); setPage(1); }}
                />
              </div>
              <div style={{ flex: '0 0 200px' }}>
                <label className="hg-label">Outcome</label>
                <select
                  className="hg-input"
                  value={outcomeFilter}
                  onChange={(e) => { setOutcomeFilter(e.target.value); setPage(1); }}
                >
                  <option value="">All outcomes</option>
                  <option value="competent">Competent</option>
                  <option value="needs_improvement">Needs Improvement</option>
                  <option value="not_assessable">Not Assessable</option>
                </select>
              </div>
            </div>
          </div>

          {isLoading && (
            <div className="hg-loading-screen">
              <div className="hg-spinner" />
              <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>Loading assessments…</span>
            </div>
          )}

          {error && !isLoading && (
            <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>{error}</div>
          )}

          {!isLoading && !error && assessments && assessments.items.length === 0 && (
            <div className="hg-card">
              <div className="hg-empty">
                <div className="hg-empty-icon">📋</div>
                <p className="hg-empty-title">No assessments on record</p>
                <p className="hg-empty-desc">
                  Create an evaluation from an active or archived diagnostic session.
                </p>
                <button className="hg-btn hg-btn-primary" style={{ marginTop: 16 }} onClick={() => setIsCreateModalOpen(true)}>
                  Create First Evaluation
                </button>
              </div>
            </div>
          )}

          {!isLoading && assessments && assessments.items.length > 0 && (
            <div className="hg-card" style={{ padding: 0, overflow: 'hidden' }}>
              <div style={{ overflowX: 'auto' }}>
                <table className="hg-table">
                  <thead>
                    <tr>
                      <th>Evaluation ID</th>
                      <th>Trainee</th>
                      <th>Session</th>
                      <th>Rubric</th>
                      <th>Score</th>
                      <th>Outcome</th>
                      <th style={{ textAlign: 'right' }}>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {assessments.items.map((a) => (
                      <tr key={a.id}>
                        <td>
                          <code className="hg-code" style={{ fontSize: 10 }}>{a.assessment_id.length > 14 ? a.assessment_id.slice(0, 14) + '…' : a.assessment_id}</code>
                        </td>
                        <td>
                          <span className="hg-badge hg-badge-orange">{a.trainee_id}</span>
                        </td>
                        <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 600 }}>
                          #{a.session_id}
                        </td>
                        <td style={{ fontSize: 12 }}>
                          <span style={{ fontWeight: 500 }}>{a.rubric_id}</span>
                          <span style={{ color: 'var(--color-warm-graphite)', marginLeft: 4 }}>v{a.rubric_version}</span>
                        </td>
                        <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 700 }}>
                          {a.score !== null ? `${a.score} / ${a.max_score ?? 100}` : (
                            <span style={{ color: 'var(--color-soft-sand)' }}>Pending</span>
                          )}
                        </td>
                        <td>{outcomeBadge(a.outcome)}</td>
                        <td style={{ textAlign: 'right' }}>
                          <button
                            className="hg-btn hg-btn-secondary"
                            style={{ padding: '5px 10px', fontSize: 12 }}
                            onClick={() => handleOpenReview(a)}
                          >
                            Trainer Review
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <div className="hg-pagination" style={{ padding: '12px 20px' }}>
                <span style={{ fontSize: 13, color: 'var(--color-warm-graphite)' }}>
                  {assessments.total} assessment{assessments.total !== 1 ? 's' : ''} · Page {page}/{totalPages}
                </span>
                <div style={{ display: 'flex', gap: 6 }}>
                  <button
                    className="hg-btn hg-btn-secondary"
                    style={{ padding: '6px 12px' }}
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                    disabled={page <= 1}
                  >
                    ← Prev
                  </button>
                  <button
                    className="hg-btn hg-btn-secondary"
                    style={{ padding: '6px 12px' }}
                    onClick={() => setPage((p) => p + 1)}
                    disabled={page >= totalPages}
                  >
                    Next →
                  </button>
                </div>
              </div>
            </div>
          )}
        </>
      )}

      {activeTab === 'rubrics' && (
        <div>
          {rubrics.length === 0 ? (
            <div className="hg-card">
              <div className="hg-empty">
                <div className="hg-empty-icon">📐</div>
                <p className="hg-empty-title">No rubrics configured</p>
                <p className="hg-empty-desc">Assessment rubrics must be added via the backend API.</p>
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {rubrics.map((r) => (
                <div key={r.id} className="hg-card">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
                    <div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                        <code className="hg-code" style={{ fontWeight: 700 }}>{r.rubric_id}</code>
                        <span className="hg-badge hg-badge-neutral">v{r.version}</span>
                        {!r.is_active && <span className="hg-badge hg-badge-danger">Inactive</span>}
                      </div>
                      <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--color-carbon)', marginBottom: 4 }}>{r.name}</div>
                      {r.description && (
                        <div style={{ fontSize: 13, color: 'var(--color-warm-graphite)' }}>{r.description}</div>
                      )}
                    </div>
                    <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', textAlign: 'right', flexShrink: 0 }}>
                      <div>Created by <strong>{r.created_by}</strong></div>
                      <div style={{ fontFamily: 'var(--font-mono)' }}>{new Date(r.created_at).toLocaleDateString()}</div>
                    </div>
                  </div>
                  {Object.keys(r.rules || {}).length > 0 && (
                    <details style={{ marginTop: 12 }}>
                      <summary style={{ fontSize: 12, fontWeight: 600, color: 'var(--color-warm-graphite)', cursor: 'pointer', userSelect: 'none' }}>
                        View rubric rules ({Object.keys(r.rules).length} criteria)
                      </summary>
                      <pre style={{
                        marginTop: 8,
                        background: 'var(--color-warm-stone)',
                        borderRadius: 6,
                        padding: '12px 14px',
                        fontSize: 11,
                        fontFamily: 'var(--font-mono)',
                        overflow: 'auto',
                        color: 'var(--color-carbon)',
                      }}>
                        {JSON.stringify(r.rules, null, 2)}
                      </pre>
                    </details>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Create Assessment Modal */}
      {isCreateModalOpen && (
        <div className="hg-modal-backdrop" onClick={(e) => { if (e.target === e.currentTarget) setIsCreateModalOpen(false); }}>
          <div className="hg-modal">
            <div className="hg-modal-header">
              <span className="hg-modal-title">Create Session Evaluation</span>
              <button className="hg-close-btn" onClick={() => setIsCreateModalOpen(false)}>×</button>
            </div>
            <div className="hg-modal-body">
              {createError && (
                <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>{createError}</div>
              )}
              <form id="create-assessment-form" onSubmit={handleCreateAssessment}>
                <div className="hg-form-group">
                  <label className="hg-label">Assessment ID *</label>
                  <input
                    type="text"
                    className="hg-input"
                    required
                    placeholder="e.g. EVAL-2026-001"
                    style={{ fontFamily: 'var(--font-mono)', textTransform: 'uppercase' }}
                    value={newAssessmentId}
                    onChange={(e) => setNewAssessmentId(e.target.value)}
                  />
                </div>
                <div className="hg-form-group">
                  <label className="hg-label">Session ID (numeric) *</label>
                  <input
                    type="number"
                    className="hg-input"
                    required
                    placeholder="e.g. 42"
                    value={newSessionId}
                    onChange={(e) => setNewSessionId(e.target.value)}
                    style={{ fontFamily: 'var(--font-mono)' }}
                  />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div className="hg-form-group">
                    <label className="hg-label">Rubric ID *</label>
                    <select
                      className="hg-input"
                      value={newRubricId}
                      onChange={(e) => setNewRubricId(e.target.value)}
                    >
                      <option value="RUBRIC-LEAK-V1">RUBRIC-LEAK-V1</option>
                      {rubrics.filter((r) => r.rubric_id !== 'RUBRIC-LEAK-V1').map((r) => (
                        <option key={r.id} value={r.rubric_id}>{r.rubric_id}</option>
                      ))}
                    </select>
                  </div>
                  <div className="hg-form-group">
                    <label className="hg-label">Rubric Version</label>
                    <input
                      type="text"
                      className="hg-input"
                      placeholder="1.0"
                      value={newRubricVersion}
                      onChange={(e) => setNewRubricVersion(e.target.value)}
                      style={{ fontFamily: 'var(--font-mono)' }}
                    />
                  </div>
                </div>
                <div className="hg-form-group">
                  <label className="hg-label">Evidence Event IDs (comma-separated)</label>
                  <input
                    type="text"
                    className="hg-input"
                    placeholder="e.g. 101, 102, 105"
                    value={newEvidenceIds}
                    onChange={(e) => setNewEvidenceIds(e.target.value)}
                    style={{ fontFamily: 'var(--font-mono)' }}
                  />
                </div>
                <div className="hg-form-group" style={{ marginBottom: 0 }}>
                  <label className="hg-label">Scoring Explanation</label>
                  <textarea
                    className="hg-input"
                    placeholder="Describe the scoring rationale…"
                    rows={3}
                    value={newScoringExplanation}
                    onChange={(e) => setNewScoringExplanation(e.target.value)}
                    style={{ resize: 'vertical' }}
                  />
                </div>
              </form>
            </div>
            <div className="hg-modal-footer">
              <button className="hg-btn hg-btn-secondary" onClick={() => setIsCreateModalOpen(false)}>Cancel</button>
              <button type="submit" form="create-assessment-form" className="hg-btn hg-btn-primary" disabled={isSubmittingNew}>
                {isSubmittingNew ? (
                  <><span className="hg-spinner" style={{ width: 14, height: 14, borderWidth: 2 }} /> Creating…</>
                ) : (
                  'Create Evaluation'
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Trainer Review Modal */}
      {selectedAssessment && (
        <div className="hg-modal-backdrop" onClick={(e) => { if (e.target === e.currentTarget) setSelectedAssessment(null); }}>
          <div className="hg-modal">
            <div className="hg-modal-header">
              <div>
                <div className="hg-modal-title">Trainer Review</div>
                <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', marginTop: 2 }}>
                  <code style={{ fontFamily: 'var(--font-mono)', fontSize: 11 }}>{selectedAssessment.assessment_id}</code>
                  &nbsp;·&nbsp;{selectedAssessment.trainee_id}
                </div>
              </div>
              <button className="hg-close-btn" onClick={() => setSelectedAssessment(null)}>×</button>
            </div>
            <div className="hg-modal-body">
              {/* Current state */}
              <div style={{
                background: 'var(--color-ivory)',
                border: '1px solid var(--color-warm-stone)',
                borderRadius: 8,
                padding: '12px 16px',
                marginBottom: 16,
                display: 'flex',
                gap: 20,
                fontSize: 12,
              }}>
                <div>
                  <div style={{ color: 'var(--color-warm-graphite)', marginBottom: 2 }}>Current Score</div>
                  <div style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 16 }}>
                    {selectedAssessment.score != null ? `${selectedAssessment.score} / ${selectedAssessment.max_score ?? 100}` : '—'}
                  </div>
                </div>
                <div>
                  <div style={{ color: 'var(--color-warm-graphite)', marginBottom: 2 }}>Current Outcome</div>
                  {outcomeBadge(selectedAssessment.outcome)}
                </div>
              </div>

              {reviewError && (
                <div className="hg-alert hg-alert-error" style={{ marginBottom: 12 }}>{reviewError}</div>
              )}
              {reviewSuccess && (
                <div className="hg-alert hg-alert-success" style={{ marginBottom: 12 }}>{reviewSuccess}</div>
              )}

              <form id="review-form" onSubmit={handleSubmitReview}>
                <div className="hg-form-group">
                  <label className="hg-label">Trainer Comments *</label>
                  <textarea
                    className="hg-input"
                    required
                    placeholder="Provide detailed feedback and reasoning for any score override…"
                    rows={4}
                    style={{ resize: 'vertical' }}
                    value={reviewComments}
                    onChange={(e) => setReviewComments(e.target.value)}
                  />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div className="hg-form-group" style={{ marginBottom: 0 }}>
                    <label className="hg-label">Override Score</label>
                    <input
                      type="number"
                      className="hg-input"
                      placeholder="Leave blank to keep"
                      value={overrideScore}
                      onChange={(e) => setOverrideScore(e.target.value)}
                      style={{ fontFamily: 'var(--font-mono)' }}
                    />
                  </div>
                  <div className="hg-form-group" style={{ marginBottom: 0 }}>
                    <label className="hg-label">Override Outcome</label>
                    <select
                      className="hg-input"
                      value={overrideOutcome}
                      onChange={(e) => setOverrideOutcome(e.target.value)}
                    >
                      <option value="">Keep current</option>
                      <option value="competent">Competent</option>
                      <option value="needs_improvement">Needs Improvement</option>
                      <option value="not_assessable">Not Assessable</option>
                    </select>
                  </div>
                </div>
              </form>
            </div>
            <div className="hg-modal-footer">
              <button className="hg-btn hg-btn-secondary" onClick={() => setSelectedAssessment(null)}>Cancel</button>
              <button type="submit" form="review-form" className="hg-btn hg-btn-primary" disabled={isSubmittingReview}>
                {isSubmittingReview ? (
                  <><span className="hg-spinner" style={{ width: 14, height: 14, borderWidth: 2 }} /> Submitting…</>
                ) : (
                  'Submit Review'
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
