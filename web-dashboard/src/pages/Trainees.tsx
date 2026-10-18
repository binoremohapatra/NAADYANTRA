import { useState, useEffect } from 'react';
import { apiClient } from '../api/client';
import type { Trainee, Session, Assessment, PaginatedResponse } from '../types';

export default function Trainees() {
  const [trainees, setTrainees] = useState<PaginatedResponse<Trainee> | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [cohortFilter, setCohortFilter] = useState('');
  const [page, setPage] = useState(1);

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [newTraineeId, setNewTraineeId] = useState('');
  const [newName, setNewName] = useState('');
  const [newCohort, setNewCohort] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  const [selectedTrainee, setSelectedTrainee] = useState<Trainee | null>(null);
  const [traineeSessions, setTraineeSessions] = useState<Session[]>([]);
  const [traineeAssessments, setTraineeAssessments] = useState<Assessment[]>([]);
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);

  useEffect(() => {
    loadTrainees();
  }, [page, search, cohortFilter]);

  const loadTrainees = async () => {
    try {
      setIsLoading(true);
      setError('');
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
  };

  const handleCreateTrainee = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTraineeId.trim() || !newName.trim()) {
      setFormError('Trainee ID and full name are required');
      return;
    }
    try {
      setIsSubmitting(true);
      setFormError('');
      await apiClient.createTrainee({
        trainee_id: newTraineeId.trim().toUpperCase(),
        name: newName.trim(),
        cohort: newCohort.trim() || undefined,
      });
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
              <path d="M6.5 1v11M1 6.5h11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
            Register Trainee
          </button>
          <button className="hg-btn hg-btn-secondary" onClick={loadTrainees}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
              <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
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
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            />
          </div>
          <div style={{ flex: '0 0 220px' }}>
            <label className="hg-label">Cohort</label>
            <input
              type="text"
              className="hg-input"
              placeholder="e.g. Cohort-2026A"
              value={cohortFilter}
              onChange={(e) => { setCohortFilter(e.target.value); setPage(1); }}
            />
          </div>
        </div>
      </div>

      {isLoading && (
        <div className="hg-loading-screen">
          <div className="hg-spinner" />
          <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>Loading trainee roster…</span>
        </div>
      )}

      {error && !isLoading && (
        <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>{error}</div>
      )}

      {!isLoading && !error && trainees && trainees.items.length === 0 && (
        <div className="hg-card">
          <div className="hg-empty">
            <div className="hg-empty-icon">👥</div>
            <p className="hg-empty-title">No trainees registered</p>
            <p className="hg-empty-desc">
              {trainees.total === 0
                ? 'Register candidates to link sessions and assessments.'
                : 'No candidates match the current search.'}
            </p>
            {trainees.total === 0 && (
              <button className="hg-btn hg-btn-primary" style={{ marginTop: 16 }} onClick={() => setIsModalOpen(true)}>
                Register First Candidate
              </button>
            )}
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
                  <th>Enrolled On</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {trainees.items.map((t) => (
                  <tr key={t.id}>
                    <td>
                      <code className="hg-code" style={{ color: 'var(--color-dark-burnt-orange)', fontWeight: 600 }}>
                        {t.trainee_id}
                      </code>
                    </td>
                    <td style={{ fontWeight: 500 }}>{t.name}</td>
                    <td>
                      {t.cohort ? (
                        <span className="hg-badge hg-badge-orange">{t.cohort}</span>
                      ) : (
                        <span style={{ color: 'var(--color-soft-sand)', fontSize: 12 }}>General</span>
                      )}
                    </td>
                    <td style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
                      {new Date(t.created_at).toLocaleDateString()}
                    </td>
                    <td>
                      {t.is_active ? (
                        <span className="hg-badge hg-badge-ok">Active</span>
                      ) : (
                        <span className="hg-badge hg-badge-neutral">Inactive</span>
                      )}
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <button
                        className="hg-btn hg-btn-secondary"
                        style={{ padding: '5px 10px', fontSize: 12 }}
                        onClick={() => handleViewPerformance(t)}
                      >
                        Performance →
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="hg-pagination" style={{ padding: '12px 20px' }}>
            <span style={{ fontSize: 13, color: 'var(--color-warm-graphite)' }}>
              {trainees.total} candidate{trainees.total !== 1 ? 's' : ''} enrolled · Page {page}/{totalPages}
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

      {/* Register Trainee Modal */}
      {isModalOpen && (
        <div className="hg-modal-backdrop" onClick={(e) => { if (e.target === e.currentTarget) setIsModalOpen(false); }}>
          <div className="hg-modal">
            <div className="hg-modal-header">
              <span className="hg-modal-title">Register Trainee</span>
              <button className="hg-close-btn" onClick={() => setIsModalOpen(false)}>×</button>
            </div>
            <div className="hg-modal-body">
              {formError && (
                <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>{formError}</div>
              )}
              <form id="trainee-form" onSubmit={handleCreateTrainee}>
                <div className="hg-form-group">
                  <label className="hg-label">Trainee ID *</label>
                  <input
                    type="text"
                    className="hg-input"
                    required
                    placeholder="e.g. T-2026-001"
                    style={{ fontFamily: 'var(--font-mono)', textTransform: 'uppercase' }}
                    value={newTraineeId}
                    onChange={(e) => setNewTraineeId(e.target.value)}
                  />
                  <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
                    Will be stored in uppercase. Must be unique.
                  </div>
                </div>
                <div className="hg-form-group">
                  <label className="hg-label">Full Name *</label>
                  <input
                    type="text"
                    className="hg-input"
                    required
                    placeholder="Candidate full name"
                    value={newName}
                    onChange={(e) => setNewName(e.target.value)}
                  />
                </div>
                <div className="hg-form-group" style={{ marginBottom: 0 }}>
                  <label className="hg-label">Cohort</label>
                  <input
                    type="text"
                    className="hg-input"
                    placeholder="e.g. Cohort-2026A (optional)"
                    value={newCohort}
                    onChange={(e) => setNewCohort(e.target.value)}
                  />
                </div>
              </form>
            </div>
            <div className="hg-modal-footer">
              <button className="hg-btn hg-btn-secondary" onClick={() => setIsModalOpen(false)}>Cancel</button>
              <button type="submit" form="trainee-form" className="hg-btn hg-btn-primary" disabled={isSubmitting}>
                {isSubmitting ? <><span className="hg-spinner" style={{ width: 14, height: 14, borderWidth: 2 }} /> Registering…</> : 'Register Candidate'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Performance Modal */}
      {selectedTrainee && (
        <div className="hg-modal-backdrop" onClick={(e) => { if (e.target === e.currentTarget) setSelectedTrainee(null); }}>
          <div className="hg-modal hg-modal-lg">
            <div className="hg-modal-header">
              <div>
                <div className="hg-modal-title">
                  <code style={{ fontFamily: 'var(--font-mono)', fontSize: 15 }}>{selectedTrainee.trainee_id}</code>
                  &nbsp;·&nbsp;{selectedTrainee.name}
                </div>
                {selectedTrainee.cohort && (
                  <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', marginTop: 2 }}>
                    {selectedTrainee.cohort}
                  </div>
                )}
              </div>
              <button className="hg-close-btn" onClick={() => setSelectedTrainee(null)}>×</button>
            </div>
            <div className="hg-modal-body">
              {isLoadingHistory ? (
                <div className="hg-loading-screen" style={{ minHeight: 120 }}>
                  <div className="hg-spinner" />
                  <span style={{ fontSize: 13, color: 'var(--color-warm-graphite)' }}>Loading performance history…</span>
                </div>
              ) : (
                <>
                  {/* Sessions */}
                  <div style={{ marginBottom: 20 }}>
                    <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 10 }}>
                      Recent Sessions ({traineeSessions.length})
                    </div>
                    {traineeSessions.length === 0 ? (
                      <p style={{ fontSize: 13, color: 'var(--color-warm-graphite)' }}>No sessions recorded.</p>
                    ) : (
                      <div style={{ overflowX: 'auto' }}>
                        <table className="hg-table" style={{ fontSize: 12 }}>
                          <thead>
                            <tr>
                              <th>Session #</th>
                              <th>Device</th>
                              <th>Started</th>
                              <th>Duration</th>
                              <th>Status</th>
                            </tr>
                          </thead>
                          <tbody>
                            {traineeSessions.map((s) => {
                              const dur = s.ended_at
                                ? `${Math.floor((new Date(s.ended_at).getTime() - new Date(s.started_at).getTime()) / 60000)}m`
                                : null;
                              return (
                                <tr key={s.id}>
                                  <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 600 }}>#{s.session_id}</td>
                                  <td><code className="hg-code">{s.device_id}</code></td>
                                  <td style={{ fontFamily: 'var(--font-mono)', color: 'var(--color-warm-graphite)' }}>
                                    {new Date(s.started_at).toLocaleString()}
                                  </td>
                                  <td style={{ fontFamily: 'var(--font-mono)' }}>{dur ?? '—'}</td>
                                  <td>
                                    {s.ended_at ? (
                                      <span className="hg-badge hg-badge-neutral">Done</span>
                                    ) : (
                                      <span className="hg-badge hg-badge-ok">Active</span>
                                    )}
                                  </td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>

                  <hr className="hg-divider" />

                  {/* Assessments */}
                  <div>
                    <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 10 }}>
                      Assessments ({traineeAssessments.length})
                    </div>
                    {traineeAssessments.length === 0 ? (
                      <p style={{ fontSize: 13, color: 'var(--color-warm-graphite)' }}>No assessments recorded.</p>
                    ) : (
                      <div style={{ overflowX: 'auto' }}>
                        <table className="hg-table" style={{ fontSize: 12 }}>
                          <thead>
                            <tr>
                              <th>ID</th>
                              <th>Rubric</th>
                              <th>Score</th>
                              <th>Outcome</th>
                              <th>Date</th>
                            </tr>
                          </thead>
                          <tbody>
                            {traineeAssessments.map((a) => (
                              <tr key={a.id}>
                                <td><code className="hg-code" style={{ fontSize: 10 }}>{a.assessment_id.slice(0, 12)}…</code></td>
                                <td style={{ fontFamily: 'var(--font-mono)' }}>{a.rubric_id}</td>
                                <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 600 }}>
                                  {a.score != null && a.max_score != null ? `${a.score}/${a.max_score}` : '—'}
                                </td>
                                <td>
                                  <span className={`hg-badge ${outcomeColor(a.outcome)}`}>
                                    {a.outcome.replace('_', ' ')}
                                  </span>
                                </td>
                                <td style={{ color: 'var(--color-warm-graphite)' }}>
                                  {new Date(a.created_at).toLocaleDateString()}
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
            </div>
            <div className="hg-modal-footer">
              <button className="hg-btn hg-btn-secondary" onClick={() => setSelectedTrainee(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
