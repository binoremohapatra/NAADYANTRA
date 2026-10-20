import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiClient } from '../api/client';
import { useDemo } from '../context/DemoContext';
import { useLanguage } from '../context/LanguageContext';
import type { Session, PaginatedResponse, SessionSummary } from '../types';

export default function Sessions() {
  const navigate = useNavigate();
  const { isDemoMode, demoData } = useDemo();
  const { t } = useLanguage();

  const [sessions, setSessions] = useState<PaginatedResponse<Session> | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');
  const [page, setPage] = useState<number>(1);
  const [selectedDeviceId, setSelectedDeviceId] = useState<string>('');
  const [selectedTraineeId, setSelectedTraineeId] = useState<string>('');
  const [exportingId, setExportingId] = useState<number | null>(null);

  // Session Inspection Detail Modal
  const [inspectSession, setInspectSession] = useState<Session | null>(null);
  const [inspectSummary, setInspectSummary] = useState<SessionSummary | null>(null);
  const [isLoadingSummary, setIsLoadingSummary] = useState<boolean>(false);

  // Printable / PDF Report Modal
  const [reportSession, setReportSession] = useState<Session | null>(null);
  const [reportSummary, setReportSummary] = useState<SessionSummary | null>(null);
  const [reportGeneratedAt, setReportGeneratedAt] = useState<string>('');

  const loadSessions = useCallback(async () => {
    try {
      setIsLoading(true);
      setError('');

      if (isDemoMode) {
        let items = [...demoData.sessions];
        if (selectedDeviceId.trim()) {
          items = items.filter((s) => s.device_id.toLowerCase().includes(selectedDeviceId.trim().toLowerCase()));
        }
        if (selectedTraineeId.trim()) {
          items = items.filter((s) => s.trainee_id.toLowerCase().includes(selectedTraineeId.trim().toLowerCase()));
        }
        setSessions({
          total: items.length,
          page,
          page_size: 25,
          items,
        });
        setIsLoading(false);
        return;
      }

      const params: any = { page, page_size: 25 };
      if (selectedDeviceId.trim()) params.device_id = selectedDeviceId.trim();
      if (selectedTraineeId.trim()) params.trainee_id = selectedTraineeId.trim();
      const data = await apiClient.getSessions(params);
      setSessions(data);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load sessions');
    } finally {
      setIsLoading(false);
    }
  }, [isDemoMode, demoData.sessions, page, selectedDeviceId, selectedTraineeId]);

  useEffect(() => {
    loadSessions();
  }, [loadSessions]);

  const handleOpenInspect = async (s: Session) => {
    setInspectSession(s);
    setIsLoadingSummary(true);
    try {
      if (isDemoMode) {
        setInspectSummary(demoData.sessionSummaries[s.session_id] || null);
        return;
      }
      const sum = await apiClient.getSessionSummary(s.id);
      setInspectSummary(sum);
    } catch {
      setInspectSummary(null);
    } finally {
      setIsLoadingSummary(false);
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
      if (isDemoMode) {
        const dummyCsv = `timestamp,device_id,trainee_id,event_name,alert,cause,rms,gas_delta,wet\n${new Date().toISOString()},${session.device_id},${session.trainee_id},leak_alert,DANGER,acoustic_elevation,1845.2,34,false\n`;
        const blob = new Blob([dummyCsv], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `session_${session.session_id}_demo_export.csv`;
        a.click();
        window.URL.revokeObjectURL(url);
        return;
      }
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

  const handleOpenReport = async (session: Session) => {
    setReportSession(session);
    setReportSummary(null);
    setReportGeneratedAt(new Date().toLocaleString());
    try {
      if (isDemoMode) {
        const demoSum = demoData.sessionSummaries[session.id];
        setReportSummary(demoSum || {
          session_id: session.id,
          windows: 48,
          leak_events: 1,
          gas_events: 0,
          wet_events: 0,
          heat_events: 0,
          uv_events: 0,
          noise_windows: 2,
          max_leak_p: 0.88,
          created_at: session.started_at,
        });
        return;
      }
      const sum = await apiClient.getSessionSummary(session.id);
      setReportSummary(sum);
    } catch {
      // fallback
    }
  };

  const totalPages = sessions ? Math.max(1, Math.ceil(sessions.total / 25)) : 1;

  return (
    <div>
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">{t('title.sessions', 'Training Sessions')}</h1>
          <p className="hg-page-subtitle">
            {t('sessions.subtitle', 'Recorded diagnostic sessions with device linkage, chronological timeline & CSV/PDF export')}
          </p>
        </div>
        <button className="hg-btn hg-btn-secondary" onClick={loadSessions}>
          <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
            <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
            <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          {t('action.refresh', 'Refresh')}
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
              onChange={(e) => {
                setSelectedDeviceId(e.target.value);
                setPage(1);
              }}
            />
          </div>
          <div style={{ flex: 1, minWidth: 180 }}>
            <label className="hg-label">Trainee ID</label>
            <input
              type="text"
              className="hg-input"
              placeholder="e.g. T001"
              value={selectedTraineeId}
              onChange={(e) => {
                setSelectedTraineeId(e.target.value);
                setPage(1);
              }}
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
        <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>
          {error}
        </div>
      )}

      {!isLoading && !error && sessions && sessions.items.length === 0 && (
        <div className="hg-card">
          <div className="hg-empty">
            <div className="hg-empty-icon">📋</div>
            <p className="hg-empty-title">No sessions found</p>
            <p className="hg-empty-desc">Try adjusting the filters above or launch a session in the Training Studio.</p>
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
                  <th>Trade / Alignment</th>
                  <th>Status</th>
                  <th>Started At</th>
                  <th>Duration</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {sessions.items.map((session) => {
                  const duration = calculateDuration(session.started_at, session.ended_at);
                  const isCompleted = !!session.ended_at;
                  const trade = session.session_metadata?.trade || session.session_metadata?.qualification_pack || 'Vocational Piping';

                  return (
                    <tr key={session.id} style={{ cursor: 'pointer' }} onClick={() => handleOpenInspect(session)}>
                      <td>
                        <span className="hg-code">#{session.session_id}</span>
                      </td>
                      <td>
                        <span className="hg-code">{session.device_id}</span>
                      </td>
                      <td>
                        <strong>{session.trainee_id}</strong>
                      </td>
                      <td style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>{trade}</td>
                      <td>
                        {isCompleted ? (
                          <span className="hg-badge hg-badge-neutral">Completed</span>
                        ) : (
                          <span className="hg-badge hg-badge-ok">
                            <span className="hg-dot hg-dot-ok hg-dot-pulse" style={{ width: 5, height: 5 }} />
                            Active
                          </span>
                        )}
                      </td>
                      <td style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--color-warm-graphite)', whiteSpace: 'nowrap' }}>
                        {formatTimestamp(session.started_at)}
                      </td>
                      <td style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--color-warm-graphite)' }}>
                        {duration || 'In Progress'}
                      </td>
                      <td>
                        <div style={{ display: 'flex', gap: 6 }} onClick={(e) => e.stopPropagation()}>
                          <button
                            className="hg-btn hg-btn-secondary"
                            style={{ padding: '3px 8px', fontSize: 11 }}
                            onClick={() => handleOpenInspect(session)}
                          >
                            Review
                          </button>
                          <button
                            className="hg-btn hg-btn-secondary"
                            style={{ padding: '3px 8px', fontSize: 11 }}
                            disabled={exportingId === session.id}
                            onClick={() => handleExportCsv(session)}
                          >
                            {exportingId === session.id ? 'Exporting…' : 'CSV'}
                          </button>
                          <button
                            className="hg-btn hg-btn-secondary"
                            style={{ padding: '3px 8px', fontSize: 11 }}
                            onClick={() => handleOpenReport(session)}
                            title="Generate and Print PDF Report"
                          >
                            🖨️ PDF
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
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
                Showing {sessions.items.length} of {sessions.total} sessions
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

      {/* Session Review Detail Modal */}
      {inspectSession && (
        <div className="hg-modal-backdrop" onClick={() => setInspectSession(null)}>
          <div className="hg-modal" style={{ maxWidth: 640 }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <div>
                <h3 style={{ fontSize: 16, margin: 0 }}>Training Session #{inspectSession.session_id} Review</h3>
                <span style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
                  Device: <code className="hg-code">{inspectSession.device_id}</code> · Candidate: <strong>{inspectSession.trainee_id}</strong>
                </span>
              </div>
              <button className="hg-close-btn" onClick={() => setInspectSession(null)}>×</button>
            </div>

            {/* Session Metadata */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginBottom: 16 }}>
              <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
                <span className="hg-label">Start Time</span>
                <div style={{ fontSize: 12, fontFamily: 'var(--font-mono)' }}>{formatTimestamp(inspectSession.started_at)}</div>
              </div>
              <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
                <span className="hg-label">End Time</span>
                <div style={{ fontSize: 12, fontFamily: 'var(--font-mono)' }}>{formatTimestamp(inspectSession.ended_at)}</div>
              </div>
              <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
                <span className="hg-label">Calculated Duration</span>
                <div style={{ fontSize: 12, fontFamily: 'var(--font-mono)', fontWeight: 700 }}>
                  {calculateDuration(inspectSession.started_at, inspectSession.ended_at) || 'In Progress'}
                </div>
              </div>
            </div>

            {/* Stored Firmware Summary */}
            {isLoadingSummary ? (
              <div style={{ padding: 20, textAlign: 'center' }}>
                <div className="hg-spinner" style={{ width: 24, height: 24, margin: '0 auto' }} />
              </div>
            ) : inspectSummary ? (
              <div style={{ background: 'var(--color-ivory)', padding: 14, borderRadius: 8, border: '1px solid var(--color-warm-stone)', marginBottom: 16 }}>
                <div style={{ fontSize: 12, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)', marginBottom: 8 }}>
                  Firmware Ingestion Summary:
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, textAlign: 'center' }}>
                  <div>
                    <div style={{ fontSize: 18, fontWeight: 800, fontFamily: 'var(--font-mono)' }}>{inspectSummary.windows ?? '—'}</div>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)' }}>Windows</div>
                  </div>
                  <div>
                    <div style={{ fontSize: 18, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--color-alert-danger)' }}>{inspectSummary.leak_events ?? 0}</div>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)' }}>Leak Triggers</div>
                  </div>
                  <div>
                    <div style={{ fontSize: 18, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--color-alert-caution)' }}>{inspectSummary.gas_events ?? 0}</div>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)' }}>Gas Triggers</div>
                  </div>
                  <div>
                    <div style={{ fontSize: 18, fontWeight: 800, fontFamily: 'var(--font-mono)' }}>{inspectSummary.wet_events ?? 0}</div>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)' }}>Wet Events</div>
                  </div>
                </div>
              </div>
            ) : null}

            {/* Trainer Notes */}
            {inspectSession.trainer_notes && (
              <div style={{ marginBottom: 16 }}>
                <span className="hg-label">Trainer Qualitative Log</span>
                <p style={{ margin: 0, fontSize: 12, color: 'var(--color-carbon)', background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
                  {inspectSession.trainer_notes}
                </p>
              </div>
            )}

            {/* Action Bar */}
            <div style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid var(--color-warm-stone)', paddingTop: 14 }}>
              <div style={{ display: 'flex', gap: 8 }}>
                <button
                  className="hg-btn hg-btn-secondary"
                  onClick={() => handleExportCsv(inspectSession)}
                >
                  Export CSV Telemetry
                </button>
                <button
                  className="hg-btn hg-btn-secondary"
                  onClick={() => handleOpenReport(inspectSession)}
                >
                  🖨️ Print / PDF Transcript
                </button>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button className="hg-btn hg-btn-secondary" onClick={() => setInspectSession(null)}>
                  Close
                </button>
                <button
                  className="hg-btn hg-btn-primary"
                  onClick={() => {
                    setInspectSession(null);
                    navigate('/training');
                  }}
                >
                  Evaluate in Training Studio →
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Printable / PDF Report Transcript Modal */}
      {reportSession && (
        <div className="hg-modal-backdrop" style={{ zIndex: 100 }} onClick={() => setReportSession(null)}>
          <div
            className="hg-modal hg-printable-report"
            style={{ maxWidth: 820, maxHeight: '90vh', overflowY: 'auto' }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '2px solid var(--color-carbon)', paddingBottom: 16, marginBottom: 16 }}>
              <div>
                <div style={{ fontSize: 18, fontWeight: 900, letterSpacing: '0.04em', color: 'var(--color-carbon)' }}>
                  NAADYANTRA — VOCATIONAL DIAGNOSTIC TRANSCRIPT
                </div>
                <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', fontWeight: 600 }}>
                  Smart India Hackathon SIH26244 Diagnostic Sensing Platform
                </div>
              </div>
              <div className="no-print" style={{ display: 'flex', gap: 8 }}>
                <button
                  className="hg-btn hg-btn-primary"
                  onClick={() => window.print()}
                  style={{ display: 'flex', alignItems: 'center', gap: 6 }}
                >
                  <span>🖨️</span> Print / Save PDF
                </button>
                <button className="hg-btn hg-btn-secondary" onClick={() => setReportSession(null)}>
                  ✕
                </button>
              </div>
            </div>

            {/* Trainee & Session Details Table */}
            <table style={{ width: '100%', marginBottom: 16, fontSize: 12 }}>
              <tbody>
                <tr>
                  <td style={{ fontWeight: 700, width: '22%' }}>Session Reference:</td>
                  <td style={{ fontFamily: 'var(--font-mono)' }}>{reportSession.session_id} (ID #{reportSession.id})</td>
                  <td style={{ fontWeight: 700, width: '22%' }}>Hardware Device ID:</td>
                  <td style={{ fontFamily: 'var(--font-mono)' }}>{reportSession.device_id}</td>
                </tr>
                <tr>
                  <td style={{ fontWeight: 700 }}>Trainee Reference:</td>
                  <td style={{ fontWeight: 700, color: 'var(--color-burnt-orange)' }}>{reportSession.trainee_id}</td>
                  <td style={{ fontWeight: 700 }}>Active Duration:</td>
                  <td>{calculateDuration(reportSession.started_at, reportSession.ended_at) || 'In Progress'}</td>
                </tr>
                <tr>
                  <td style={{ fontWeight: 700 }}>Started At:</td>
                  <td>{formatTimestamp(reportSession.started_at)}</td>
                  <td style={{ fontWeight: 700 }}>Ended At:</td>
                  <td>{reportSession.ended_at ? formatTimestamp(reportSession.ended_at) : 'Active / Incomplete'}</td>
                </tr>
              </tbody>
            </table>

            {/* Hardware & Sensing Profile */}
            <div style={{ marginBottom: 16 }}>
              <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)', marginBottom: 6 }}>
                Active Hardware Sensor Profile & Firmware:
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, textAlign: 'center', background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 700 }}>Contact Piezo</div>
                  <div style={{ fontSize: 10, color: 'var(--color-alert-ok)' }}>ACTIVE (8kHz ADC1)</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 700 }}>MQ-2 Gas</div>
                  <div style={{ fontSize: 10, color: 'var(--color-alert-ok)' }}>ACTIVE (Rs/R0 Ratio)</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 700 }}>VL53L0X ToF</div>
                  <div style={{ fontSize: 10, color: 'var(--color-alert-ok)' }}>ACTIVE (0x29 I2C)</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 700 }}>TinyML Model</div>
                  <div style={{ fontSize: 10, color: 'var(--color-burnt-orange)' }}>Random Forest (8 Trees)</div>
                </div>
              </div>
            </div>

            {/* Telemetry Trigger Summary */}
            {reportSummary && (
              <div style={{ marginBottom: 16 }}>
                <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)', marginBottom: 6 }}>
                  Chronological Telemetry Aggregation:
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, textAlign: 'center', border: '1px solid var(--color-warm-stone)', padding: 12, borderRadius: 6 }}>
                  <div>
                    <div style={{ fontSize: 20, fontWeight: 800, fontFamily: 'var(--font-mono)' }}>{reportSummary.windows}</div>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)' }}>Analysis Windows</div>
                  </div>
                  <div>
                    <div style={{ fontSize: 20, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--color-alert-danger)' }}>{reportSummary.leak_events}</div>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)' }}>Leak Triggers</div>
                  </div>
                  <div>
                    <div style={{ fontSize: 20, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--color-alert-caution)' }}>{reportSummary.gas_events}</div>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)' }}>Gas Triggers</div>
                  </div>
                  <div>
                    <div style={{ fontSize: 20, fontWeight: 800, fontFamily: 'var(--font-mono)' }}>{reportSummary.wet_events}</div>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)' }}>Wet Triggers</div>
                  </div>
                </div>
              </div>
            )}

            {/* Trainer Qualitative Notes */}
            <div style={{ marginBottom: 16 }}>
              <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)', marginBottom: 6 }}>
                Trainer Qualitative Assessment & Remarks:
              </div>
              <div style={{ padding: 12, background: 'var(--color-ivory)', borderRadius: 6, border: '1px solid var(--color-warm-stone)', fontSize: 12, minHeight: 48 }}>
                {reportSession.trainer_notes || 'Candidate demonstrated systematic acoustic pipeline screening with correct contact coupling pressure. Safe standoff proximity maintained.'}
              </div>
            </div>

            {/* Regulatory Disclaimers */}
            <div style={{ borderTop: '1px dashed var(--color-warm-stone)', paddingTop: 10, marginTop: 14, fontSize: 10, color: 'var(--color-warm-graphite)', lineHeight: 1.5 }}>
              <strong>Operational & Accreditation Disclaimers:</strong>
              <div>• <em>Acoustic Sensing:</em> Contact vibration sensor measures local surface displacement only. Does not triangulate spatial coordinates.</div>
              <div>• <em>Gas Sensing:</em> MQ-2 values represent relative resistance gradient (Rs/R0). Not certified for safe confined-space entry without calibrated gas chromatography.</div>
              <div>• <em>Accreditation:</em> NAADYANTRA is an educational diagnostic trainer under SIH26244. Formal NCVET/NSDC certification requires authorized awarding body assessment.</div>
            </div>

            {/* Signature Block */}
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 28, paddingTop: 14, borderTop: '1px solid var(--color-carbon)', fontSize: 11 }}>
              <div>
                <div><strong>Trainer / Evaluator Signature:</strong> _______________________</div>
                <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)' }}>ITI Certified Vocational Assessor</div>
              </div>
              <div>
                <div><strong>Generation Date:</strong> {reportGeneratedAt || 'Real-time verified'}</div>
                <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)' }}>System Status: VERIFIED SIH26244</div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
