import { useState, useEffect, useCallback } from 'react';
import { apiClient } from '../api/client';
import { useDemo } from '../context/DemoContext';
import type { Trainee, Session, Assessment, PaginatedResponse } from '../types';

export default function Trainees() {
  const { isDemoMode, demoData } = useDemo();

  const [trainees, setTrainees] = useState<PaginatedResponse<Trainee> | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');
  const [search, setSearch] = useState<string>('');
  const [cohortFilter, setCohortFilter] = useState<string>('');
  const [page, setPage] = useState<number>(1);

  const [isModalOpen, setIsModalOpen] = useState<boolean>(false);
  const [newTraineeId, setNewTraineeId] = useState<string>('');
  const [newName, setNewName] = useState<string>('');
  const [newCohort, setNewCohort] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);
  const [formError, setFormError] = useState<string>('');

  const [selectedTrainee, setSelectedTrainee] = useState<Trainee | null>(null);
  const [traineeSessions, setTraineeSessions] = useState<Session[]>([]);
  const [traineeAssessments, setTraineeAssessments] = useState<Assessment[]>([]);
  const [isLoadingHistory, setIsLoadingHistory] = useState<boolean>(false);

  const loadTrainees = useCallback(async () => {
    try {
      setIsLoading(true);
      setError('');

      if (isDemoMode) {
        let items = [...demoData.trainees];
        if (search.trim()) {
          const q = search.trim().toLowerCase();
          items = items.filter(
            (t) => t.trainee_id.toLowerCase().includes(q) || t.name.toLowerCase().includes(q)
          );
        }
        if (cohortFilter.trim()) {
          items = items.filter(
            (t) => t.cohort && t.cohort.toLowerCase().includes(cohortFilter.trim().toLowerCase())
          );
        }
        setTrainees({
          total: items.length,
          page,
          page_size: 25,
          items,
        });
        setIsLoading(false);
        return;
      }

      const params: any = { page, page_size: 25 };
      if (search.trim()) params.search = search.trim();
      if (cohortFilter.trim()) params.cohort = cohortFilter.trim();
      const res = await apiClient.getTrainees(params);
      setTrainees(res);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load trainee directory');
    } finally {
      setIsLoading(false);
    }
  }, [isDemoMode, demoData.trainees, page, search, cohortFilter]);

  useEffect(() => {
    loadTrainees();
  }, [loadTrainees]);

  const handleCreateTrainee = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTraineeId.trim() || !newName.trim()) {
      setFormError('Trainee ID and full name are required');
      return;
    }
    try {
      setIsSubmitting(true);
      setFormError('');

      if (!isDemoMode) {
        await apiClient.createTrainee({
          trainee_id: newTraineeId.trim().toUpperCase(),
          name: newName.trim(),
          cohort: newCohort.trim() || undefined,
        });
      }

      setIsModalOpen(false);
      setNewTraineeId('');
      setNewName('');
      setNewCohort('');
      await loadTrainees();
    } catch (err: any) {
      setFormError(err.response?.data?.detail || 'Failed to create trainee record');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleViewPerformance = async (t: Trainee) => {
    setSelectedTrainee(t);
    setIsLoadingHistory(true);
    try {
      if (isDemoMode) {
        const sess = demoData.sessions.filter((s) => s.trainee_id === t.trainee_id);
        const assess = demoData.assessments.filter((a) => a.trainee_id === t.trainee_id);
        setTraineeSessions(sess);
        setTraineeAssessments(assess);
        return;
      }
      const [sessRes, assessRes] = await Promise.all([
        apiClient.getTraineeSessions(t.trainee_id, { page: 1, page_size: 10 }),
        apiClient.getTraineeAssessments(t.trainee_id, { page: 1, page_size: 10 }),
      ]);
      setTraineeSessions(sessRes.items);
      setTraineeAssessments(assessRes.items);
    } catch (err) {
      console.error('Failed to load performance details', err);
    } finally {
      setIsLoadingHistory(false);
    }
  };

  const totalPages = trainees ? Math.max(1, Math.ceil(trainees.total / 25)) : 1;

  const outcomeColor = (outcome: string) => {
    if (outcome === 'competent') return 'hg-badge-ok';
    if (outcome === 'needs_improvement') return 'hg-badge-caution';
    return 'hg-badge-neutral';
  };

  return (
    <div>
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">Trainee Directory</h1>
          <p className="hg-page-subtitle">
            Vocational candidates enrolled in acoustic inspection and hazard diagnostic training
          </p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button className="hg-btn hg-btn-primary" onClick={() => setIsModalOpen(true)}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M6.5 1v11M1 6.5h11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
            Register Trainee
          </button>
          <button className="hg-btn hg-btn-secondary" onClick={loadTrainees}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
              <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            Refresh
          </button>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="hg-card" style={{ marginBottom: 20, padding: '16px 20px' }}>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          <div style={{ flex: 1, minWidth: 200 }}>
            <label className="hg-label">Search</label>
            <input
              type="text"
              className="hg-input"
              placeholder="Search by ID or name…"
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
            />
          </div>
          <div style={{ flex: '0 0 220px' }}>
            <label className="hg-label">Cohort</label>
            <input
              type="text"
              className="hg-input"
              placeholder="e.g. Cohort-2026A"
              value={cohortFilter}
              onChange={(e) => {
                setCohortFilter(e.target.value);
                setPage(1);
              }}
            />
          </div>
        </div>
      </div>

      {isLoading && (
        <div className="hg-loading-screen">
          <div className="hg-spinner" />
          <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>Loading trainees…</span>
        </div>
      )}

      {error && !isLoading && (
        <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>
          {error}
        </div>
      )}

      {!isLoading && !error && trainees && trainees.items.length === 0 && (
        <div className="hg-card">
          <div className="hg-empty">
            <div className="hg-empty-icon">👥</div>
            <p className="hg-empty-title">No trainees found</p>
            <p className="hg-empty-desc">Register a new candidate or adjust search filters.</p>
          </div>
        </div>
      )}

      {!isLoading && trainees && trainees.items.length > 0 && (
        <div className="hg-card" style={{ padding: 0, overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table className="hg-table">
              <thead>
                <tr>
                  <th>Trainee ID</th>
                  <th>Full Name</th>
                  <th>Cohort</th>
                  <th>Trade Focus</th>
                  <th>Status</th>
                  <th>Enrolled Date</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {trainees.items.map((t) => (
                  <tr key={t.id}>
                    <td>
                      <span className="hg-code">{t.trainee_id}</span>
                    </td>
                    <td>
                      <strong>{t.name}</strong>
                    </td>
                    <td>
                      <span className="hg-badge hg-badge-neutral">{t.cohort || 'General'}</span>
                    </td>
                    <td style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
                      {t.trainee_metadata?.trade || 'Piping / HVAC'}
                    </td>
                    <td>
                      {t.is_active ? (
                        <span className="hg-badge hg-badge-ok">Active</span>
                      ) : (
                        <span className="hg-badge hg-badge-danger">Inactive</span>
                      )}
                    </td>
                    <td style={{ fontSize: 12, color: 'var(--color-warm-graphite)', whiteSpace: 'nowrap' }}>
                      {new Date(t.created_at).toLocaleDateString()}
                    </td>
                    <td>
                      <button
                        className="hg-btn hg-btn-secondary"
                        style={{ padding: '3px 8px', fontSize: 11 }}
                        onClick={() => handleViewPerformance(t)}
                      >
                        Performance History
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {totalPages > 1 && (
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                padding: '12px 20px',
                borderTop: '1px solid var(--color-warm-stone)',
                background: 'var(--color-ivory)',
                fontSize: 12,
                color: 'var(--color-warm-graphite)',
              }}
            >
              <span>
                Showing {trainees.items.length} of {trainees.total} trainees
              </span>
              <div style={{ display: 'flex', gap: 6 }}>
                <button
                  className="hg-btn hg-btn-secondary"
                  style={{ padding: '4px 10px', fontSize: 11 }}
                  disabled={page <= 1}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                >
                  Previous
                </button>
                <span style={{ display: 'flex', alignItems: 'center', padding: '0 8px', fontFamily: 'var(--font-mono)' }}>
                  Page {page} of {totalPages}
                </span>
                <button
                  className="hg-btn hg-btn-secondary"
                  style={{ padding: '4px 10px', fontSize: 11 }}
                  disabled={page >= totalPages}
                  onClick={() => setPage((p) => p + 1)}
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Trainee Registration Modal */}
      {isModalOpen && (
        <div className="hg-modal-backdrop" onClick={() => setIsModalOpen(false)}>
          <div className="hg-modal" style={{ maxWidth: 440 }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h3 style={{ fontSize: 16, margin: 0 }}>Register New Trainee</h3>
              <button className="hg-close-btn" onClick={() => setIsModalOpen(false)}>×</button>
            </div>
            <form onSubmit={handleCreateTrainee}>
              <div style={{ marginBottom: 14 }}>
                <label className="hg-label">Trainee Identifier</label>
                <input
                  type="text"
                  className="hg-input"
                  placeholder="e.g. T004"
                  value={newTraineeId}
                  onChange={(e) => setNewTraineeId(e.target.value)}
                  required
                />
              </div>
              <div style={{ marginBottom: 14 }}>
                <label className="hg-label">Full Name</label>
                <input
                  type="text"
                  className="hg-input"
                  placeholder="e.g. Rajesh Verma"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  required
                />
              </div>
              <div style={{ marginBottom: 20 }}>
                <label className="hg-label">Cohort / Batch</label>
                <input
                  type="text"
                  className="hg-input"
                  placeholder="e.g. ITI-PLUMB-2026-B"
                  value={newCohort}
                  onChange={(e) => setNewCohort(e.target.value)}
                />
              </div>
              {formError && <div className="hg-alert hg-alert-error" style={{ marginBottom: 14 }}>{formError}</div>}
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
                <button type="button" className="hg-btn hg-btn-secondary" onClick={() => setIsModalOpen(false)}>
                  Cancel
                </button>
                <button type="submit" className="hg-btn hg-btn-primary" disabled={isSubmitting}>
                  {isSubmitting ? 'Registering…' : 'Register Candidate'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Performance History Modal */}
      {selectedTrainee && (
        <div className="hg-modal-backdrop" onClick={() => setSelectedTrainee(null)}>
          <div className="hg-modal" style={{ maxWidth: 680 }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <div>
                <h3 style={{ fontSize: 16, margin: 0 }}>Candidate Diagnostic Performance</h3>
                <span style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
                  {selectedTrainee.name} (<code className="hg-code">{selectedTrainee.trainee_id}</code>) · {selectedTrainee.cohort || 'General'}
                </span>
              </div>
              <button className="hg-close-btn" onClick={() => setSelectedTrainee(null)}>×</button>
            </div>

            {isLoadingHistory ? (
              <div className="hg-loading-screen" style={{ padding: 30 }}>
                <div className="hg-spinner" />
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                {/* Completed Assessments Sub-table */}
                <div>
                  <div style={{ fontSize: 12, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)', marginBottom: 8 }}>
                    NSQF Skill Assessments ({traineeAssessments.length})
                  </div>
                  {traineeAssessments.length === 0 ? (
                    <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', background: 'var(--color-ivory)', padding: 12, borderRadius: 6 }}>
                      No evaluations recorded yet for this candidate.
                    </div>
                  ) : (
                    <table className="hg-table" style={{ fontSize: 12 }}>
                      <thead>
                        <tr>
                          <th>ID</th>
                          <th>Rubric</th>
                          <th>Score</th>
                          <th>Outcome</th>
                        </tr>
                      </thead>
                      <tbody>
                        {traineeAssessments.map((a) => (
                          <tr key={a.id}>
                            <td><span className="hg-code">{a.assessment_id}</span></td>
                            <td>{a.rubric_id}</td>
                            <td><strong>{a.score ?? '—'} / {a.max_score ?? 100}</strong></td>
                            <td><span className={`hg-badge ${outcomeColor(a.outcome)}`}>{a.outcome}</span></td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>

                {/* Training Sessions Sub-table */}
                <div>
                  <div style={{ fontSize: 12, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)', marginBottom: 8 }}>
                    Diagnostic Sessions ({traineeSessions.length})
                  </div>
                  {traineeSessions.length === 0 ? (
                    <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', background: 'var(--color-ivory)', padding: 12, borderRadius: 6 }}>
                      No sessions recorded.
                    </div>
                  ) : (
                    <table className="hg-table" style={{ fontSize: 12 }}>
                      <thead>
                        <tr>
                          <th>Session ID</th>
                          <th>Device</th>
                          <th>Started</th>
                          <th>Status</th>
                        </tr>
                      </thead>
                      <tbody>
                        {traineeSessions.map((s) => (
                          <tr key={s.id}>
                            <td><span className="hg-code">#{s.session_id}</span></td>
                            <td><span className="hg-code">{s.device_id}</span></td>
                            <td>{new Date(s.started_at).toLocaleDateString()}</td>
                            <td>
                              <span className={`hg-badge ${s.ended_at ? 'hg-badge-neutral' : 'hg-badge-ok'}`}>
                                {s.ended_at ? 'Completed' : 'Active'}
                              </span>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              </div>
            )}

            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 20 }}>
              <button className="hg-btn hg-btn-secondary" onClick={() => setSelectedTrainee(null)}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
