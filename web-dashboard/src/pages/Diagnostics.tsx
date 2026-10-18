import { useState, useEffect, useCallback } from 'react';
import { apiClient } from '../api/client';
import { useDemo } from '../context/DemoContext';
import type { Event } from '../types';

export default function Diagnostics() {
  const { isDemoMode, demoData } = useDemo();

  const [events, setEvents] = useState<Event[]>([]);
  const [totalCount, setTotalCount] = useState<number>(0);
  const [page, setPage] = useState<number>(1);
  const [pageSize] = useState<number>(20);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');

  // Filters
  const [selectedDevice, setSelectedDevice] = useState<string>('');
  const [selectedAlert, setSelectedAlert] = useState<string>('');
  const [selectedModality, setSelectedModality] = useState<string>('all');
  const [searchTerm, setSearchTerm] = useState<string>('');

  // Selected event for inspection drawer
  const [inspectEvent, setInspectEvent] = useState<Event | null>(null);
  const [isCopied, setIsCopied] = useState<boolean>(false);

  const loadEvents = useCallback(async () => {
    try {
      setIsLoading(true);
      setError('');

      if (isDemoMode) {
        let filtered = [...demoData.events];
        if (selectedDevice) {
          filtered = filtered.filter((e) => e.device_id === selectedDevice);
        }
        if (selectedAlert) {
          filtered = filtered.filter((e) => e.alert === selectedAlert);
        }
        if (selectedModality === 'acoustic') {
          filtered = filtered.filter((e) => e.rms != null && e.rms > 0);
        } else if (selectedModality === 'gas') {
          filtered = filtered.filter((e) => e.gas_delta != null && e.gas_delta > 0);
        } else if (selectedModality === 'moisture') {
          filtered = filtered.filter((e) => e.wet != null);
        }
        if (searchTerm) {
          const q = searchTerm.toLowerCase();
          filtered = filtered.filter(
            (e) =>
              e.device_id.toLowerCase().includes(q) ||
              (e.cause && e.cause.toLowerCase().includes(q)) ||
              (e.event_name && e.event_name.toLowerCase().includes(q)) ||
              (e.trainee_id && e.trainee_id.toLowerCase().includes(q))
          );
        }
        setTotalCount(filtered.length);
        const start = (page - 1) * pageSize;
        setEvents(filtered.slice(start, start + pageSize));
        return;
      }

      const res = await apiClient.getDeviceEvents({
        page,
        page_size: pageSize,
        device_id: selectedDevice || undefined,
        alert: selectedAlert || undefined,
      });

      let items = res.items || [];
      if (selectedModality === 'acoustic') {
        items = items.filter((e) => e.rms != null && e.rms > 0);
      } else if (selectedModality === 'gas') {
        items = items.filter((e) => e.gas_delta != null && e.gas_delta > 0);
      } else if (selectedModality === 'moisture') {
        items = items.filter((e) => e.wet != null);
      }

      setEvents(items);
      setTotalCount(res.total);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load diagnostic events');
    } finally {
      setIsLoading(false);
    }
  }, [isDemoMode, demoData.events, selectedDevice, selectedAlert, selectedModality, searchTerm, page, pageSize]);

  useEffect(() => {
    loadEvents();
  }, [loadEvents]);

  const copyPayload = (payload: any) => {
    navigator.clipboard.writeText(JSON.stringify(payload, null, 2));
    setIsCopied(true);
    setTimeout(() => setIsCopied(false), 2000);
  };

  // Helper to determine exact observation diagnostic state
  const getObservationState = (ev: Event) => {
    if (ev.alert === 'DANGER') {
      return {
        label: 'CRITICAL ALERT',
        className: 'hg-state-critical',
        dot: 'hg-dot-danger',
        desc: 'Sustained abnormal threshold breach requiring trainer intervention.',
      };
    }
    if (ev.alert === 'CAUTION') {
      return {
        label: 'WARNING OBSERVATION',
        className: 'hg-state-warning',
        dot: 'hg-dot-caution',
        desc: 'Elevated sensor activity detected above baseline.',
      };
    }
    if (ev.cause === 'normal_baseline' || ev.event_name === 'baseline_sweep') {
      return {
        label: 'NORMAL BASELINE',
        className: 'hg-state-normal',
        dot: 'hg-dot-ok',
        desc: 'Calibration window within expected ambient noise floor.',
      };
    }
    if (ev.rms == null && ev.gas_delta == null && ev.wet == null) {
      return {
        label: 'DATA INCOMPLETE',
        className: 'hg-state-incomplete',
        dot: 'hg-dot-neutral',
        desc: 'Telemetry packet lacked sensor measurement payloads.',
      };
    }
    return {
      label: 'NORMAL OBSERVATION',
      className: 'hg-state-normal',
      dot: 'hg-dot-ok',
      desc: 'Observation within normal operational parameters.',
    };
  };

  // Explainable feedback generator based on real signal properties
  const getExplainableFeedback = (ev: Event) => {
    const findings: string[] = [];
    const remediation: string[] = [];
    let inferenceSource = 'Deterministic RMS Heuristic (FW 1.1.0 fallback)';

    if (ev.model_label && ev.model_label.includes('(rms)')) {
      inferenceSource = 'Embedded Heuristic Ratio: (RMS / RMS_base) / 4.0';
    } else if (ev.model_label && ev.model_label.includes('rf')) {
      inferenceSource = 'Python Random Forest Classifier (Synthetic Training Baseline)';
    }

    // Acoustic Analysis
    if (ev.rms != null) {
      if (ev.rms >= 1200) {
        findings.push(
          `High acoustic energy detected (${ev.rms.toFixed(1)} counts). Sustained local vibration indicates potential pressurized fluid or gas jetting.`
        );
        remediation.push(
          'Perform comparative sweep on adjoining pipe couplings. Isolate the fitting with highest consecutive RMS elevation.'
        );
      } else if (ev.rms >= 600) {
        findings.push(
          `Moderate vibration (${ev.rms.toFixed(1)} counts). Signal exceeds quiet ambient threshold (<600 counts).`
        );
        remediation.push(
          'Verify steady probe contact pressure. Ensure contact probe tip is held perpendicular to fitting surface.'
        );
      } else {
        findings.push(
          `Quiet acoustic level (${ev.rms.toFixed(1)} counts). Consistent with clean baseline or low-noise pipe section.`
        );
      }
    }

    // Gas Analysis
    if (ev.gas_delta != null && ev.gas_delta > 100) {
      findings.push(
        `Indicative MQ-2 delta elevation (+${ev.gas_delta} ADC counts, Rs/R0: ${ev.gas_ratio?.toFixed(3) ?? '—'}). Combustible vapor gradient detected.`
      );
      remediation.push(
        'Situational Awareness Notice: Uncalibrated relative reading only. Does NOT certify area clear or replace calibrated LEL instruments.'
      );
    }

    // Moisture Analysis
    if (ev.wet === true) {
      findings.push(
        'Surface moisture conduction probe triggered (wet: 1). Conductive liquid layer detected across sensing electrodes.'
      );
      remediation.push(
        'Inspect for pipe sweating, joint seepage, or surface condensation. Dry probe before testing electrical joints.'
      );
    }

    return {
      findings,
      remediation,
      inferenceSource,
    };
  };

  return (
    <div>
      {/* Page Header */}
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">Diagnostic Workspace</h1>
          <p className="hg-page-subtitle">
            Acoustic signal verification, environmental hazard screening &amp; explainable feedback
          </p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button className="hg-btn hg-btn-secondary" onClick={loadEvents} disabled={isLoading}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
              <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            Refresh
          </button>
        </div>
      </div>

      {/* Safety & Calibration Legal Notice Banner */}
      <div
        style={{
          background: 'rgba(240, 120, 66, 0.08)',
          border: '1px solid rgba(240, 120, 66, 0.25)',
          borderRadius: 8,
          padding: '12px 16px',
          marginBottom: 20,
          display: 'flex',
          gap: 12,
          alignItems: 'flex-start',
        }}
      >
        <span style={{ fontSize: 16 }}>⚠️</span>
        <div style={{ fontSize: 12, lineHeight: 1.5, color: 'var(--color-carbon)' }}>
          <strong style={{ color: 'var(--color-dark-burnt-orange)' }}>
            Instrument Calibration &amp; Diagnostic Protocol Disclosures:
          </strong>
          <span style={{ color: 'var(--color-warm-graphite)', display: 'block', marginTop: 2 }}>
            1. <strong>Contact Acoustic Piezo</strong> captures localized mechanical vibration only — it does{' '}
            <em>not</em> perform automatic spatial triangulation.
            <br />
            2. <strong>MQ-2 Gas Readings</strong> represent uncalibrated relative ADC deviations — never interpret them as certified ppm or %LEL for confined space entry.
            <br />
            3. <strong>Negative Diagnostic Rule</strong>: A pipeline is <em>not</em> proven leak-free merely because the current acoustic reading does not exceed threshold.
          </span>
        </div>
      </div>

      {/* Filters Bar */}
      <div className="hg-filters" style={{ background: 'var(--color-white)', padding: 14, borderRadius: 8, border: '1px solid var(--color-warm-stone)', marginBottom: 20 }}>
        <div style={{ minWidth: 160 }}>
          <label className="hg-label">Device Rig</label>
          <select
            className="hg-input"
            value={selectedDevice}
            onChange={(e) => {
              setSelectedDevice(e.target.value);
              setPage(1);
            }}
          >
            <option value="">All Devices</option>
            {isDemoMode ? (
              demoData.devices.map((d) => (
                <option key={d.device_id} value={d.device_id}>
                  {d.device_id} ({d.name})
                </option>
              ))
            ) : (
              <>
                <option value="SIH-DEV-01">SIH-DEV-01</option>
                <option value="SIH-DEV-02">SIH-DEV-02</option>
              </>
            )}
          </select>
        </div>

        <div style={{ minWidth: 140 }}>
          <label className="hg-label">Severity Level</label>
          <select
            className="hg-input"
            value={selectedAlert}
            onChange={(e) => {
              setSelectedAlert(e.target.value);
              setPage(1);
            }}
          >
            <option value="">All Severities</option>
            <option value="DANGER">Critical (DANGER)</option>
            <option value="CAUTION">Warning (CAUTION)</option>
            <option value="OK">Normal (OK)</option>
          </select>
        </div>

        <div style={{ minWidth: 160 }}>
          <label className="hg-label">Sensor Modality</label>
          <select
            className="hg-input"
            value={selectedModality}
            onChange={(e) => {
              setSelectedModality(e.target.value);
              setPage(1);
            }}
          >
            <option value="all">All Sensor Modalities</option>
            <option value="acoustic">Acoustic Contact Piezo (RMS)</option>
            <option value="gas">Combustible Gas (MQ-2 Delta)</option>
            <option value="moisture">Moisture Conduction (Wet/Dry)</option>
          </select>
        </div>

        <div style={{ flex: 1, minWidth: 180 }}>
          <label className="hg-label">Search Keyword</label>
          <input
            type="text"
            className="hg-input"
            placeholder="Search device, cause, or trainee ID..."
            value={searchTerm}
            onChange={(e) => {
              setSearchTerm(e.target.value);
              setPage(1);
            }}
          />
        </div>

        {(selectedDevice || selectedAlert || selectedModality !== 'all' || searchTerm) && (
          <div style={{ display: 'flex', alignItems: 'flex-end' }}>
            <button
              className="hg-btn hg-btn-ghost"
              onClick={() => {
                setSelectedDevice('');
                setSelectedAlert('');
                setSelectedModality('all');
                setSearchTerm('');
                setPage(1);
              }}
              style={{ fontSize: 12 }}
            >
              Reset Filters
            </button>
          </div>
        )}
      </div>

      {/* Events Table Container */}
      <div className="hg-card" style={{ padding: 0, overflow: 'hidden' }}>
        {isLoading ? (
          <div className="hg-loading-screen" style={{ padding: 40 }}>
            <div className="hg-spinner" />
            <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>Loading diagnostic observations...</span>
          </div>
        ) : error ? (
          <div style={{ padding: 24, color: 'var(--color-alert-danger)', fontSize: 13 }}>{error}</div>
        ) : events.length === 0 ? (
          <div className="hg-empty" style={{ padding: 48 }}>
            <div className="hg-empty-icon">🔍</div>
            <p className="hg-empty-title">No Diagnostic Observations Match Filters</p>
            <p className="hg-empty-desc">Adjust severity or modality filters to view recorded telemetry.</p>
          </div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table className="hg-table">
              <thead>
                <tr>
                  <th>Timestamp</th>
                  <th>Device / Session</th>
                  <th>Diagnostic State</th>
                  <th>Acoustic RMS</th>
                  <th>Leak Prob.</th>
                  <th>Gas Delta (Rs/R0)</th>
                  <th>Moisture</th>
                  <th>Inference Source</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {events.map((ev) => {
                  const state = getObservationState(ev);
                  return (
                    <tr key={ev.id} style={{ cursor: 'pointer' }} onClick={() => setInspectEvent(ev)}>
                      <td style={{ whiteSpace: 'nowrap', fontFamily: 'var(--font-mono)', fontSize: 12 }}>
                        {new Date(ev.server_timestamp).toLocaleTimeString()}
                        <span style={{ display: 'block', fontSize: 10, color: 'var(--color-warm-graphite)' }}>
                          {new Date(ev.server_timestamp).toLocaleDateString()}
                        </span>
                      </td>
                      <td>
                        <span className="hg-code">{ev.device_id}</span>
                        <span style={{ display: 'block', fontSize: 11, color: 'var(--color-warm-graphite)', marginTop: 2 }}>
                          Session #{ev.session_id} · {ev.trainee_id}
                        </span>
                      </td>
                      <td>
                        <span className={`hg-state-badge ${state.className}`}>
                          <span className={`hg-dot ${state.dot}`} />
                          {state.label}
                        </span>
                      </td>
                      <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 600 }}>
                        {ev.rms != null ? (
                          <span style={{ color: ev.rms >= 1200 ? 'var(--color-alert-danger)' : 'var(--color-carbon)' }}>
                            {ev.rms.toFixed(1)} <span style={{ fontSize: 10, fontWeight: 400, color: 'var(--color-warm-graphite)' }}>cts</span>
                          </span>
                        ) : (
                          <span style={{ color: 'var(--color-warm-graphite)' }}>—</span>
                        )}
                      </td>
                      <td style={{ fontFamily: 'var(--font-mono)' }}>
                        {ev.leak_probability != null ? (
                          <span
                            style={{
                              fontWeight: 600,
                              color:
                                ev.leak_probability >= 0.75
                                  ? 'var(--color-alert-danger)'
                                  : ev.leak_probability >= 0.5
                                  ? 'var(--color-alert-caution)'
                                  : 'var(--color-alert-ok)',
                            }}
                          >
                            {(ev.leak_probability * 100).toFixed(0)}%
                          </span>
                        ) : (
                          <span style={{ color: 'var(--color-warm-graphite)' }}>—</span>
                        )}
                      </td>
                      <td style={{ fontFamily: 'var(--font-mono)' }}>
                        {ev.gas_delta != null ? (
                          <span>
                            +{ev.gas_delta}{' '}
                            <span style={{ fontSize: 11, color: 'var(--color-warm-graphite)' }}>
                              ({ev.gas_ratio != null ? ev.gas_ratio.toFixed(2) : '—'})
                            </span>
                          </span>
                        ) : (
                          <span style={{ color: 'var(--color-warm-graphite)' }}>—</span>
                        )}
                      </td>
                      <td>
                        {ev.wet === true ? (
                          <span className="hg-badge hg-badge-danger">WET (FILM)</span>
                        ) : ev.wet === false ? (
                          <span className="hg-badge hg-badge-ok">DRY</span>
                        ) : (
                          <span style={{ color: 'var(--color-warm-graphite)' }}>—</span>
                        )}
                      </td>
                      <td style={{ fontSize: 11, color: 'var(--color-warm-graphite)', maxWidth: 140 }}>
                        <span style={{ fontWeight: 500, color: 'var(--color-carbon)' }}>
                          {ev.model_label || 'Heuristic Fallback'}
                        </span>
                      </td>
                      <td>
                        <button
                          className="hg-btn hg-btn-secondary"
                          style={{ padding: '4px 10px', fontSize: 11 }}
                          onClick={(e) => {
                            e.stopPropagation();
                            setInspectEvent(ev);
                          }}
                        >
                          Inspect
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* Pagination Bar */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '12px 20px',
            borderTop: '1px solid var(--color-warm-stone)',
            background: 'var(--color-ivory)',
            fontSize: 12,
            color: 'var(--color-warm-graphite)',
          }}
        >
          <span>
            Showing {events.length} of {totalCount} observations
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
              Page {page}
            </span>
            <button
              className="hg-btn hg-btn-secondary"
              style={{ padding: '4px 10px', fontSize: 11 }}
              disabled={events.length < pageSize}
              onClick={() => setPage((p) => p + 1)}
            >
              Next
            </button>
          </div>
        </div>
      </div>

      {/* Slide-out Event Detail & Explainable Feedback Drawer */}
      {inspectEvent && (
        <div className="hg-drawer-overlay" onClick={() => setInspectEvent(null)}>
          <div className="hg-drawer" onClick={(e) => e.stopPropagation()}>
            {/* Drawer Header */}
            <div
              style={{
                padding: '20px 24px',
                borderBottom: '1px solid var(--color-warm-stone)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                position: 'sticky',
                top: 0,
                background: 'var(--color-white)',
                zIndex: 10,
              }}
            >
              <div>
                <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>
                  Observation Inspection Panel
                </div>
                <h2 style={{ fontSize: 18, margin: '2px 0 0', color: 'var(--color-carbon)' }}>
                  Event #{inspectEvent.id} · <span className="hg-code">{inspectEvent.device_id}</span>
                </h2>
              </div>
              <button className="hg-close-btn" onClick={() => setInspectEvent(null)}>
                ×
              </button>
            </div>

            {/* Drawer Content */}
            <div style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: 20 }}>
              {/* Primary Observation Card */}
              <div
                style={{
                  background: 'var(--color-ivory)',
                  border: '1px solid var(--color-warm-stone)',
                  borderRadius: 8,
                  padding: 16,
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                  <span className={`hg-state-badge ${getObservationState(inspectEvent).className}`}>
                    <span className={`hg-dot ${getObservationState(inspectEvent).dot}`} />
                    {getObservationState(inspectEvent).label}
                  </span>
                  <span style={{ fontSize: 11, fontFamily: 'var(--font-mono)', color: 'var(--color-warm-graphite)' }}>
                    {new Date(inspectEvent.server_timestamp).toLocaleString()}
                  </span>
                </div>
                <p style={{ margin: 0, fontSize: 13, color: 'var(--color-carbon)', lineHeight: 1.5 }}>
                  {getObservationState(inspectEvent).desc}
                </p>
              </div>

              {/* Explainable Diagnostic Feedback */}
              {(() => {
                const feedback = getExplainableFeedback(inspectEvent);
                return (
                  <div className="hg-card" style={{ padding: 18 }}>
                    <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span>💡</span> Explainable Diagnostic Feedback
                    </div>
                    <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', marginBottom: 12, fontFamily: 'var(--font-mono)' }}>
                      Inference Engine: <strong>{feedback.inferenceSource}</strong>
                    </div>

                    <div style={{ marginBottom: 12 }}>
                      <strong style={{ fontSize: 12, color: 'var(--color-carbon)' }}>System Observations:</strong>
                      <ul style={{ margin: '6px 0 0', paddingLeft: 18, fontSize: 12, color: 'var(--color-warm-graphite)', lineHeight: 1.6 }}>
                        {feedback.findings.map((f, i) => (
                          <li key={i}>{f}</li>
                        ))}
                      </ul>
                    </div>

                    {feedback.remediation.length > 0 && (
                      <div style={{ background: 'rgba(240, 120, 66, 0.08)', borderRadius: 6, padding: 12, border: '1px solid rgba(240, 120, 66, 0.2)' }}>
                        <strong style={{ fontSize: 12, color: 'var(--color-dark-burnt-orange)' }}>
                          Trainer &amp; Trainee Guidance:
                        </strong>
                        <ul style={{ margin: '6px 0 0', paddingLeft: 18, fontSize: 12, color: 'var(--color-carbon)', lineHeight: 1.6 }}>
                          {feedback.remediation.map((r, i) => (
                            <li key={i}>{r}</li>
                          ))}
                        </ul>
                      </div>
                    )}
                  </div>
                );
              })()}

              {/* Multi-Modal Sensor Metrics Grid */}
              <div className="hg-card" style={{ padding: 18 }}>
                <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 14 }}>
                  Sensor Telemetry Readout
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
                  <div style={{ background: 'var(--color-ivory)', padding: 12, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
                    <div style={{ fontSize: 10, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)' }}>
                      Acoustic RMS
                    </div>
                    <div style={{ fontSize: 18, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--color-carbon)', marginTop: 4 }}>
                      {inspectEvent.rms != null ? inspectEvent.rms.toFixed(1) : '—'}{' '}
                      <span style={{ fontSize: 11, fontWeight: 400, color: 'var(--color-warm-graphite)' }}>counts</span>
                    </div>
                  </div>

                  <div style={{ background: 'var(--color-ivory)', padding: 12, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
                    <div style={{ fontSize: 10, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)' }}>
                      Heuristic Leak Prob.
                    </div>
                    <div style={{ fontSize: 18, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--color-carbon)', marginTop: 4 }}>
                      {inspectEvent.leak_probability != null ? `${(inspectEvent.leak_probability * 100).toFixed(0)}%` : '—'}
                    </div>
                  </div>

                  <div style={{ background: 'var(--color-ivory)', padding: 12, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
                    <div style={{ fontSize: 10, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)' }}>
                      MQ-2 Delta (ADC)
                    </div>
                    <div style={{ fontSize: 18, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--color-carbon)', marginTop: 4 }}>
                      {inspectEvent.gas_delta != null ? `+${inspectEvent.gas_delta}` : '—'}
                    </div>
                  </div>

                  <div style={{ background: 'var(--color-ivory)', padding: 12, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
                    <div style={{ fontSize: 10, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)' }}>
                      MQ-2 Rs/R0 Ratio
                    </div>
                    <div style={{ fontSize: 18, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--color-carbon)', marginTop: 4 }}>
                      {inspectEvent.gas_ratio != null ? inspectEvent.gas_ratio.toFixed(3) : '—'}
                    </div>
                  </div>

                  <div style={{ background: 'var(--color-ivory)', padding: 12, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
                    <div style={{ fontSize: 10, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)' }}>
                      Moisture State
                    </div>
                    <div style={{ fontSize: 18, fontWeight: 800, fontFamily: 'var(--font-mono)', marginTop: 4, color: inspectEvent.wet ? 'var(--color-alert-danger)' : 'var(--color-alert-ok)' }}>
                      {inspectEvent.wet === true ? 'WET (CONDUCTION)' : inspectEvent.wet === false ? 'DRY' : '—'}
                    </div>
                  </div>

                  <div style={{ background: 'var(--color-ivory)', padding: 12, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
                    <div style={{ fontSize: 10, fontWeight: 700, textTransform: 'uppercase', color: 'var(--color-warm-graphite)' }}>
                      Device Uptime
                    </div>
                    <div style={{ fontSize: 18, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--color-carbon)', marginTop: 4 }}>
                      {inspectEvent.device_uptime_ms != null ? `${(inspectEvent.device_uptime_ms / 1000).toFixed(0)}s` : '—'}
                    </div>
                  </div>
                </div>

                {/* Hardware Disabled Flags in FW 1.1.0 */}
                <div style={{ marginTop: 14, paddingTop: 14, borderTop: '1px solid var(--color-warm-stone)' }}>
                  <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--color-warm-graphite)', textTransform: 'uppercase', marginBottom: 8 }}>
                    Optional Modalities (Hardware Status in FW 1.1.0):
                  </div>
                  <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                    <span className="hg-state-badge hg-state-disabled" title="MLX90614 Contactless IR Pyrometer disabled in leak_detector.ino (HAS_HEAT_SENSOR 0)">
                      Heat Sensor: Disabled in FW
                    </span>
                    <span className="hg-state-badge hg-state-disabled" title="GUVA-S12SD UV Radiometer disabled in leak_detector.ino (HAS_UV_SENSOR 0)">
                      UV Sensor: Disabled in FW
                    </span>
                    <span className="hg-state-badge hg-state-disabled" title="VL53L0X Distance Sensor disabled in leak_detector.ino (HAS_DISTANCE_SENSOR 0)">
                      Distance Sensor: Disabled in FW
                    </span>
                  </div>
                </div>
              </div>

              {/* Raw JSON Payload Inspector */}
              <div className="hg-card" style={{ padding: 18 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
                  <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)' }}>
                    Raw Telemetry Payload
                  </div>
                  <button
                    className="hg-btn hg-btn-secondary"
                    style={{ padding: '4px 10px', fontSize: 11 }}
                    onClick={() => copyPayload(inspectEvent.raw_payload || inspectEvent)}
                  >
                    {isCopied ? 'Copied!' : 'Copy JSON'}
                  </button>
                </div>
                <pre
                  style={{
                    background: 'var(--color-code-bg)',
                    padding: 12,
                    borderRadius: 6,
                    fontSize: 11,
                    fontFamily: 'var(--font-mono)',
                    color: 'var(--color-carbon)',
                    overflowX: 'auto',
                    margin: 0,
                    maxHeight: 220,
                  }}
                >
                  {JSON.stringify(inspectEvent.raw_payload || inspectEvent, null, 2)}
                </pre>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
