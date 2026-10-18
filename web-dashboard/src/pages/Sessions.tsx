import { useState, useEffect } from 'react';
import { apiClient } from '../api/client';
import type { Session, PaginatedResponse } from '../types';

function Sessions() {
  const [sessions, setSessions] = useState<PaginatedResponse<Session> | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [selectedDeviceId, setSelectedDeviceId] = useState('');
  const [selectedTraineeId, setSelectedTraineeId] = useState('');
  const [exportingId, setExportingId] = useState<number | null>(null);

  useEffect(() => {
    loadSessions();
  }, [page, selectedDeviceId, selectedTraineeId]);

  const loadSessions = async () => {
    try {
      setIsLoading(true);
      setError('');
      const params: any = { page, page_size: 25 };
      if (selectedDeviceId) params.device_id = selectedDeviceId;
      if (selectedTraineeId) params.trainee_id = selectedTraineeId;
      const data = await apiClient.getSessions(params);
      setSessions(data);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load sessions');
    } finally {
      setIsLoading(false);
    }
  };

  const formatTimestamp = (timestamp: string | null) => {
    if (!timestamp) return '—';
    return new Date(timestamp).toLocaleString();
  };

  const calculateDuration = (start: string, end: string | null) => {
    if (!end) return null;
    const sec = Math.max(0, Math.floor((new Date(end).getTime() - new Date(start).getTime()) / 1000));
    const mins = Math.floor(sec / 60);
    const remSec = sec % 60;
    return `${mins}m ${remSec}s`;
  };

  const handleExportCsv = async (session: Session) => {
    setExportingId(session.id);
    try {
      const res = await apiClient.exportSessionCsv(session.id);
      const blob = new Blob([res.data], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = res.filename || `session_${session.id}_export.csv`;
      a.click();
      window.URL.revokeObjectURL(url);
    } catch {
      alert('Failed to export session telemetry CSV');
    } finally {
      setExportingId(null);
    }
  };

  const totalPages = sessions ? Math.max(1, Math.ceil(sessions.total / 25)) : 1;

  return (
    <div>
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">Training Sessions</h1>
          <p className="hg-page-subtitle">
            Recorded diagnostic sessions with device linkage and CSV export
          </p>
        </div>
        <button className="hg-btn hg-btn-secondary" onClick={loadSessions}>
          <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
            <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
            <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          Refresh
        </button>
      </div>

      {/* Filter Bar */}
      <div className="hg-card" style={{ marginBottom: 20, padding: '16px 20px' }}>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          <div style={{ flex: 1, minWidth: 180 }}>
            <label className="hg-label">Device ID</label>
            <input
              type="text"
              className="hg-input"
              placeholder="e.g. SIH-DEV-01"
              value={selectedDeviceId}
              onChange={(e) => { setSelectedDeviceId(e.target.value); setPage(1); }}
            />
          </div>
          <div style={{ flex: 1, minWidth: 180 }}>
            <label className="hg-label">Trainee ID</label>
            <input
              type="text"
              className="hg-input"
              placeholder="e.g. T001"
              value={selectedTraineeId}
              onChange={(e) => { setSelectedTraineeId(e.target.value); setPage(1); }}
            />
          </div>
        </div>
      </div>

      {isLoading && (
        <div className="hg-loading-screen">
          <div className="hg-spinner" />
          <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>Loading sessions…</span>
        </div>
      )}

      {error && !isLoading && (
        <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>{error}</div>
      )}

      {!isLoading && !error && sessions && sessions.items.length === 0 && (
        <div className="hg-card">
          <div className="hg-empty">
            <div className="hg-empty-icon">📋</div>
            <p className="hg-empty-title">No sessions found</p>
            <p className="hg-empty-desc">Try adjusting the filters above.</p>
          </div>
        </div>
      )}

      {!isLoading && sessions && sessions.items.length > 0 && (
        <div className="hg-card" style={{ padding: 0, overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table className="hg-table">
              <thead>
                <tr>
                  <th>Session ID</th>
                  <th>Device ID</th>
                  <th>Trainee</th>
                  <th>Started</th>
                  <th>Duration</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {sessions.items.map((session) => {
                  const duration = calculateDuration(session.started_at, session.ended_at);
                  return (
                    <tr key={session.id}>
                      <td>
                        <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 600, color: 'var(--color-carbon)' }}>
                          #{session.session_id}
                        </span>
                      </td>
                      <td><code className="hg-code">{session.device_id}</code></td>
                      <td>
                        <span className="hg-badge hg-badge-orange">{session.trainee_id}</span>
                      </td>
                      <td>
                        <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--color-warm-graphite)' }}>
                          {formatTimestamp(session.started_at)}
                        </span>
                      </td>
                      <td>
                        <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12 }}>
                          {duration ?? '—'}
                        </span>
                      </td>
                      <td>
                        {session.ended_at ? (
                          <span className="hg-badge hg-badge-neutral">Completed</span>
                        ) : (
                          <span className="hg-badge hg-badge-ok">
                            <span className="hg-dot hg-dot-ok hg-dot-pulse" style={{ width: 6, height: 6 }} />
                            Active
                          </span>
                        )}
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <button
                          className="hg-btn hg-btn-secondary"
                          style={{ padding: '5px 10px', fontSize: 12 }}
                          onClick={() => handleExportCsv(session)}
                          disabled={exportingId === session.id}
                        >
                          {exportingId === session.id ? (
                            <span className="hg-spinner" style={{ width: 12, height: 12, borderWidth: 2 }} />
                          ) : (
                            <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                              <path d="M6 1v6M3 5l3 3 3-3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
                              <path d="M1 9v1a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1V9" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
                            </svg>
                          )}
                          CSV
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className="hg-pagination" style={{ padding: '12px 20px' }}>
            <span style={{ fontSize: 13, color: 'var(--color-warm-graphite)' }}>
              {sessions.total} total session{sessions.total !== 1 ? 's' : ''} · Page {page}/{totalPages}
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
    </div>
  );
}

export default Sessions;
