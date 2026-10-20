import { useState, useEffect, useCallback, useRef } from 'react';
import { Link } from 'react-router-dom';
import { apiClient } from '../api/client';
import { useDemo } from '../context/DemoContext';
import { computeDeviceFreshness, getExplainableInsight, type ExplainableInsight } from '../utils/telemetry';
import type { Event, Device } from '../types';

export default function LiveFeed() {
  const { isDemoMode, demoData } = useDemo();

  const [events, setEvents] = useState<Event[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isPolling, setIsPolling] = useState<boolean>(true);
  const [pollingIntervalMs, setPollingIntervalMs] = useState<number>(5000);
  const [lastRefreshedAt, setLastRefreshedAt] = useState<Date | null>(null);
  const [error, setError] = useState<string>('');

  // Filters
  const [selectedDevice, setSelectedDevice] = useState<string>('all');
  const [selectedSeverity, setSelectedSeverity] = useState<string>('all');
  const [selectedModality, setSelectedModality] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [viewMode, setViewMode] = useState<'cards' | 'table'>('cards');

  // Audio alert toggle
  const [soundEnabled, setSoundEnabled] = useState<boolean>(false);
  const audioContextRef = useRef<AudioContext | null>(null);

  // Inspection Drawer
  const [inspectedEvent, setInspectedEvent] = useState<Event | null>(null);
  const [inspectedInsight, setInspectedInsight] = useState<ExplainableInsight | null>(null);
  const [copiedPayload, setCopiedPayload] = useState<boolean>(false);

  // Play synthesized warning tone for critical events using Web Audio API
  const playAlertChime = useCallback(() => {
    if (!soundEnabled) return;
    try {
      if (!audioContextRef.current) {
        audioContextRef.current = new (window.AudioContext || (window as any).webkitAudioContext)();
      }
      const ctx = audioContextRef.current;
      if (ctx.state === 'suspended') {
        ctx.resume();
      }
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(880, ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(440, ctx.currentTime + 0.25);
      gain.gain.setValueAtTime(0.15, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.25);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.25);
    } catch {
      // Audio context may be restricted before user gesture
    }
  }, [soundEnabled]);

  // Load registered devices for filter dropdown
  useEffect(() => {
    async function loadDevicesList() {
      try {
        if (isDemoMode) {
          setDevices(demoData.devices);
          return;
        }
        const res = await apiClient.getDevices({ page: 1, page_size: 100 });
        setDevices(res.items);
      } catch {
        // keep empty
      }
    }
    loadDevicesList();
  }, [isDemoMode, demoData.devices]);

  // Fetch telemetry events
  const fetchFeedEvents = useCallback(async (isInitial = false) => {
    try {
      if (isInitial) setIsLoading(true);
      setError('');

      if (isDemoMode) {
        let items = [...demoData.events];
        // Sort newest first
        items.sort((a, b) => new Date(b.server_timestamp).getTime() - new Date(a.server_timestamp).getTime());
        setEvents(items);
        setLastRefreshedAt(new Date());
        setIsLoading(false);
        return;
      }

      const params: any = {
        page: 1,
        page_size: 60,
      };
      if (selectedDevice !== 'all') {
        params.device_id = selectedDevice;
      }
      if (selectedSeverity !== 'all') {
        params.alert = selectedSeverity;
      }

      const res = await apiClient.getDeviceEvents(params);
      const incoming = res.items || [];

      // Check for incoming critical alerts to trigger sound
      const hasNewCritical = incoming.slice(0, 5).some((e) => e.alert === 'DANGER');
      if (hasNewCritical) {
        playAlertChime();
      }

      setEvents(incoming);
      setLastRefreshedAt(new Date());
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to poll telemetry feed from backend');
    } finally {
      if (isInitial) setIsLoading(false);
    }
  }, [isDemoMode, demoData.events, selectedDevice, selectedSeverity, playAlertChime]);

  // Polling lifecycle
  useEffect(() => {
    fetchFeedEvents(true);
    if (!isPolling) return;

    const timer = setInterval(() => {
      fetchFeedEvents(false);
    }, pollingIntervalMs);

    return () => clearInterval(timer);
  }, [fetchFeedEvents, isPolling, pollingIntervalMs]);

  // Filter events locally by modality and search text
  const filteredEvents = events.filter((ev) => {
    if (selectedDevice !== 'all' && ev.device_id !== selectedDevice) return false;
    if (selectedSeverity !== 'all' && ev.alert !== selectedSeverity) return false;

    if (selectedModality === 'acoustic') {
      if (ev.rms == null || ev.rms === 0) return false;
    } else if (selectedModality === 'gas') {
      if ((ev.gas_delta == null || ev.gas_delta === 0) && ev.gas_ratio == null) return false;
    } else if (selectedModality === 'moisture') {
      if (ev.wet == null) return false;
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const matchDevice = ev.device_id?.toLowerCase().includes(q);
      const matchCause = ev.cause?.toLowerCase().includes(q);
      const matchTrainee = ev.trainee_id?.toLowerCase().includes(q);
      const matchName = ev.event_name?.toLowerCase().includes(q);
      const matchKind = ev.event_kind?.toLowerCase().includes(q);
      if (!matchDevice && !matchCause && !matchTrainee && !matchName && !matchKind) return false;
    }

    return true;
  });

  const handleInspect = (ev: Event) => {
    setInspectedEvent(ev);
    setInspectedInsight(getExplainableInsight(ev));
    setCopiedPayload(false);
  };

  const copyInspectedPayload = () => {
    if (!inspectedEvent) return;
    navigator.clipboard.writeText(JSON.stringify(inspectedEvent, null, 2));
    setCopiedPayload(true);
    setTimeout(() => setCopiedPayload(false), 2000);
  };

  // Metrics
  const criticalCount = filteredEvents.filter((e) => e.alert === 'DANGER').length;
  const gasCount = filteredEvents.filter((e) => (e.gas_delta != null && e.gas_delta > 150) || (e.gas_ratio != null && e.gas_ratio < 0.85)).length;
  const wetCount = filteredEvents.filter((e) => e.wet === true).length;

  return (
    <div>
      {/* Header */}
      <div className="hg-page-header">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <h1 className="hg-page-title">Combined Active Telemetry Feed</h1>
            {isPolling ? (
              <span className="hg-badge hg-badge-ok">
                <span className="hg-dot hg-dot-ok hg-dot-pulse" style={{ width: 6, height: 6 }} />
                POLLING ACTIVE
              </span>
            ) : (
              <span className="hg-badge hg-badge-caution">
                <span className="hg-dot hg-dot-caution" style={{ width: 6, height: 6 }} />
                FEED PAUSED
              </span>
            )}
            {isDemoMode && (
              <span className="hg-badge hg-badge-caution" style={{ fontWeight: 700 }}>
                [DEMO / SIMULATED FEED]
              </span>
            )}
          </div>
          <p className="hg-page-subtitle">
            Consolidated diagnostic observations from all registered NAADYANTRA wearable sensing rigs
          </p>
        </div>

        {/* Polling & Audio Controls */}
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
          {/* Polling Interval Selector */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: 'var(--color-warm-graphite)' }}>
            <span>Interval:</span>
            <select
              className="hg-select"
              style={{ padding: '4px 8px', fontSize: 12 }}
              value={pollingIntervalMs}
              onChange={(e) => setPollingIntervalMs(Number(e.target.value))}
            >
              <option value={3000}>3s (Fast)</option>
              <option value={5000}>5s (Default)</option>
              <option value={10000}>10s (Relaxed)</option>
              <option value={30000}>30s (Low-Bandwidth)</option>
            </select>
          </div>

          {/* Sound Toggle */}
          <button
            className={`hg-btn ${soundEnabled ? 'hg-btn-secondary' : 'hg-btn-secondary'}`}
            style={{ padding: '6px 12px', fontSize: 12 }}
            onClick={() => setSoundEnabled(!soundEnabled)}
            title={soundEnabled ? 'Disable audible alarm chime' : 'Enable audible alarm chime on critical alerts'}
          >
            {soundEnabled ? '🔊 Sound: ON' : '🔈 Sound: OFF'}
          </button>

          {/* Pause / Resume Button */}
          <button
            className={`hg-btn ${isPolling ? 'hg-btn-secondary' : 'hg-btn-primary'}`}
            style={{ padding: '6px 14px', fontSize: 12 }}
            onClick={() => setIsPolling(!isPolling)}
          >
            {isPolling ? '⏸ Pause Polling' : '▶ Resume Polling'}
          </button>

          {/* Manual Refresh */}
          <button
            className="hg-btn hg-btn-secondary"
            style={{ padding: '6px 12px', fontSize: 12 }}
            onClick={() => fetchFeedEvents(false)}
            title="Poll now"
          >
            ↻ Poll Now
          </button>
        </div>
      </div>

      {/* Architecture & Refresh Disclosure */}
      <div
        className="hg-card"
        style={{
          marginBottom: 16,
          padding: '12px 18px',
          background: 'var(--color-pure-white)',
          borderLeft: '4px solid var(--color-burnt-orange)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: 12,
        }}
      >
        <div style={{ fontSize: 12, color: 'var(--color-carbon)' }}>
          <strong>Architecture Transparency:</strong> Central backend ingestion feed (`GET /api/v1/events`).
          Incoming observations originate from distinct hardware sensor rigs and are separated by stable <span className="hg-code">device_id</span>.
          No sensor readings from different rigs are cross-merged.
        </div>
        <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', fontFamily: 'var(--font-mono)' }}>
          Last Polled: {lastRefreshedAt ? lastRefreshedAt.toLocaleTimeString() : 'Pending…'}
        </div>
      </div>

      {/* Metrics Banner */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
          gap: 12,
          marginBottom: 16,
        }}
      >
        <div className="hg-card" style={{ padding: '12px 16px' }}>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>Stream Count</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: 'var(--color-carbon)', marginTop: 4 }}>
            {filteredEvents.length} <span style={{ fontSize: 11, fontWeight: 400 }}>events</span>
          </div>
        </div>

        <div className="hg-card" style={{ padding: '12px 16px', borderLeft: criticalCount > 0 ? '4px solid var(--color-dark-orange)' : undefined }}>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>Critical / Danger</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: criticalCount > 0 ? 'var(--color-burnt-orange)' : 'var(--color-carbon)', marginTop: 4 }}>
            {criticalCount}
          </div>
        </div>

        <div className="hg-card" style={{ padding: '12px 16px' }}>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>Gas Gradients</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: gasCount > 0 ? '#b45309' : 'var(--color-carbon)', marginTop: 4 }}>
            {gasCount}
          </div>
        </div>

        <div className="hg-card" style={{ padding: '12px 16px' }}>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>Moisture Bridges</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: wetCount > 0 ? '#2563eb' : 'var(--color-carbon)', marginTop: 4 }}>
            {wetCount}
          </div>
        </div>

        <div className="hg-card" style={{ padding: '12px 16px' }}>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>Known Fleet Rigs</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: 'var(--color-carbon)', marginTop: 4 }}>
            {devices.length} <span style={{ fontSize: 11, fontWeight: 400 }}>devices</span>
          </div>
        </div>
      </div>

      {/* Filter Toolbar */}
      <div className="hg-card" style={{ marginBottom: 16, padding: '16px 20px' }}>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          {/* Device Filter */}
          <div style={{ minWidth: 160 }}>
            <label className="hg-label">Source Device</label>
            <select
              className="hg-select"
              value={selectedDevice}
              onChange={(e) => setSelectedDevice(e.target.value)}
            >
              <option value="all">All Devices ({devices.length})</option>
              {devices.map((d) => (
                <option key={d.device_id} value={d.device_id}>
                  {d.device_id} {d.name ? `(${d.name})` : ''}
                </option>
              ))}
            </select>
          </div>

          {/* Severity Filter */}
          <div style={{ minWidth: 130 }}>
            <label className="hg-label">Severity Level</label>
            <select
              className="hg-select"
              value={selectedSeverity}
              onChange={(e) => setSelectedSeverity(e.target.value)}
            >
              <option value="all">All Severities</option>
              <option value="DANGER">Critical (DANGER)</option>
              <option value="CAUTION">Caution / Warning</option>
              <option value="NORMAL">Normal Telemetry</option>
            </select>
          </div>

          {/* Modality Filter */}
          <div style={{ minWidth: 140 }}>
            <label className="hg-label">Active Modality</label>
            <select
              className="hg-select"
              value={selectedModality}
              onChange={(e) => setSelectedModality(e.target.value)}
            >
              <option value="all">All Modalities</option>
              <option value="acoustic">Acoustic Piezo (RMS)</option>
              <option value="gas">Combustible Gas (MQ-2)</option>
              <option value="moisture">Liquid Conduction (Wet)</option>
            </select>
          </div>

          {/* Search Query */}
          <div style={{ flex: 1, minWidth: 200 }}>
            <label className="hg-label">Filter Text</label>
            <input
              type="text"
              className="hg-input"
              placeholder="Filter by device, cause, trainee ID…"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>

          {/* View Mode Toggle */}
          <div>
            <label className="hg-label">View Mode</label>
            <div className="hg-tabs">
              <button
                className={`hg-tab${viewMode === 'cards' ? ' active' : ''}`}
                onClick={() => setViewMode('cards')}
              >
                Cards
              </button>
              <button
                className={`hg-tab${viewMode === 'table' ? ' active' : ''}`}
                onClick={() => setViewMode('table')}
              >
                Table
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Error Banner */}
      {error && (
        <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>
          {error}
        </div>
      )}

      {/* Loading state */}
      {isLoading && events.length === 0 && (
        <div className="hg-loading-screen">
          <div className="hg-spinner" />
          <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>Connecting to live telemetry feed…</span>
        </div>
      )}

      {/* Empty State */}
      {!isLoading && filteredEvents.length === 0 && (
        <div className="hg-card">
          <div className="hg-empty">
            <div className="hg-empty-icon">📡</div>
            <p className="hg-empty-title">No telemetry events match your criteria</p>
            <p className="hg-empty-desc">
              Ensure registered ESP32 devices are powered on and transmitting, or relax your severity/modality filters.
            </p>
          </div>
        </div>
      )}

      {/* CARDS VIEW */}
      {!isLoading && viewMode === 'cards' && filteredEvents.length > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {filteredEvents.map((ev) => {
            const isDanger = ev.alert === 'DANGER';
            const isCaution = ev.alert === 'CAUTION';
            const insight = getExplainableInsight(ev);
            const freshness = computeDeviceFreshness(ev.server_timestamp, 60, 300);

            return (
              <div
                key={ev.id || `${ev.device_id}-${ev.server_timestamp}`}
                className="hg-card"
                style={{
                  padding: 16,
                  borderLeft: isDanger
                    ? '4px solid var(--color-burnt-orange)'
                    : isCaution
                    ? '4px solid #f59e0b'
                    : '4px solid var(--color-warm-stone)',
                  background: isDanger ? 'rgba(240, 120, 66, 0.04)' : undefined,
                  transition: 'box-shadow 0.2s ease',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 10 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                    {/* Device Link */}
                    <Link
                      to={`/devices/${ev.device_id}`}
                      className="hg-code"
                      style={{ fontWeight: 700, fontSize: 13, textDecoration: 'none' }}
                      title="View Device Details"
                    >
                      {ev.device_id}
                    </Link>

                    {/* Severity Badge */}
                    {isDanger ? (
                      <span className="hg-badge hg-badge-danger">CRITICAL ALERT</span>
                    ) : isCaution ? (
                      <span className="hg-badge hg-badge-caution">CAUTION</span>
                    ) : (
                      <span className="hg-badge hg-badge-ok">NORMAL</span>
                    )}

                    {/* Freshness Badge */}
                    <span className={`hg-badge ${freshness.badgeClass}`} style={{ fontSize: 10 }}>
                      {freshness.label}
                    </span>

                    {/* Trainee & Session Badges */}
                    {ev.trainee_id && (
                      <span className="hg-badge hg-badge-neutral" style={{ fontSize: 10 }}>
                        Trainee: {ev.trainee_id}
                      </span>
                    )}
                    {ev.session_id > 0 && (
                      <Link
                        to="/sessions"
                        className="hg-badge hg-badge-neutral"
                        style={{ fontSize: 10, textDecoration: 'none' }}
                        title="View session records"
                      >
                        Session #{ev.session_id}
                      </Link>
                    )}
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontSize: 11, fontFamily: 'var(--font-mono)', color: 'var(--color-warm-graphite)' }}>
                      {new Date(ev.server_timestamp).toLocaleTimeString()} · {new Date(ev.server_timestamp).toLocaleDateString()}
                    </span>
                    <button
                      className="hg-btn hg-btn-secondary"
                      style={{ padding: '3px 8px', fontSize: 11 }}
                      onClick={() => handleInspect(ev)}
                    >
                      Explain &amp; Payload
                    </button>
                  </div>
                </div>

                {/* Event Headline & Cause */}
                <div style={{ marginTop: 8 }}>
                  <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--color-carbon)' }}>
                    {insight.headline}
                  </div>
                  {ev.cause && (
                    <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', marginTop: 2 }}>
                      Trigger Cause: <strong>{ev.cause}</strong>
                    </div>
                  )}
                </div>

                {/* Available Sensor Measurements Grid */}
                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))',
                    gap: 8,
                    marginTop: 12,
                    paddingTop: 10,
                    borderTop: '1px solid var(--color-warm-stone)',
                  }}
                >
                  {/* Acoustic RMS */}
                  <div style={{ background: 'var(--color-ivory)', padding: '6px 10px', borderRadius: 4 }}>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>Piezo RMS</div>
                    <div style={{ fontSize: 13, fontWeight: 700, fontFamily: 'var(--font-mono)', color: 'var(--color-carbon)' }}>
                      {ev.rms != null ? `${ev.rms} cts` : <span style={{ color: 'var(--color-warm-graphite)', fontWeight: 400 }}>N/A</span>}
                    </div>
                  </div>

                  {/* Leak Probability & Model Label */}
                  <div style={{ background: 'var(--color-ivory)', padding: '6px 10px', borderRadius: 4 }}>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>Inference / Prob</div>
                    <div style={{ fontSize: 13, fontWeight: 700, fontFamily: 'var(--font-mono)', color: 'var(--color-carbon)' }}>
                      {ev.leak_probability != null ? `${(ev.leak_probability * 100).toFixed(0)}%` : '—'}
                      <span style={{ fontSize: 10, fontWeight: 400, marginLeft: 4, color: 'var(--color-warm-graphite)' }}>
                        {ev.model_label || '(rms)'}
                      </span>
                    </div>
                  </div>

                  {/* MQ-2 Gas Delta */}
                  <div style={{ background: 'var(--color-ivory)', padding: '6px 10px', borderRadius: 4 }}>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>MQ-2 Gas ΔADC</div>
                    <div style={{ fontSize: 13, fontWeight: 700, fontFamily: 'var(--font-mono)', color: 'var(--color-carbon)' }}>
                      {ev.gas_delta != null ? `+${ev.gas_delta}` : <span style={{ color: 'var(--color-warm-graphite)', fontWeight: 400 }}>N/A</span>}
                      {ev.gas_ratio != null && (
                        <span style={{ fontSize: 10, fontWeight: 400, marginLeft: 4, color: 'var(--color-warm-graphite)' }}>
                          Rs/R0: {ev.gas_ratio.toFixed(2)}
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Moisture Conduction */}
                  <div style={{ background: 'var(--color-ivory)', padding: '6px 10px', borderRadius: 4 }}>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>Moisture Probe</div>
                    <div style={{ fontSize: 13, fontWeight: 700, fontFamily: 'var(--font-mono)' }}>
                      {ev.wet === true ? (
                        <span style={{ color: '#2563eb' }}>WET (BRIDGE)</span>
                      ) : ev.wet === false ? (
                        <span style={{ color: 'var(--color-warm-graphite)' }}>DRY</span>
                      ) : (
                        <span style={{ color: 'var(--color-warm-graphite)', fontWeight: 400 }}>N/A</span>
                      )}
                    </div>
                  </div>

                  {/* Battery Voltage */}
                  <div style={{ background: 'var(--color-ivory)', padding: '6px 10px', borderRadius: 4 }}>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>LiPo Battery</div>
                    <div style={{ fontSize: 13, fontWeight: 700, fontFamily: 'var(--font-mono)', color: 'var(--color-carbon)' }}>
                      {ev.battery_v != null ? `${ev.battery_v.toFixed(2)}V` : <span style={{ color: 'var(--color-warm-graphite)', fontWeight: 400 }}>N/A</span>}
                    </div>
                  </div>

                  {/* Optional Sensors State */}
                  <div style={{ background: 'var(--color-ivory)', padding: '6px 10px', borderRadius: 4 }}>
                    <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>IR / UV / Dist</div>
                    <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)' }}>
                      {ev.temperature != null ? `${ev.temperature}°C` : 'Disabled in FW 1.1.0'}
                    </div>
                  </div>
                </div>

                {/* Diagnostic Rationale Snippet */}
                <div style={{ marginTop: 10, fontSize: 12, color: 'var(--color-carbon)' }}>
                  <strong>Diagnostic Insight:</strong> {insight.rationale}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* TABLE VIEW */}
      {!isLoading && viewMode === 'table' && filteredEvents.length > 0 && (
        <div className="hg-card" style={{ padding: 0, overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table className="hg-table">
              <thead>
                <tr>
                  <th>Timestamp</th>
                  <th>Device ID</th>
                  <th>Severity</th>
                  <th>Piezo RMS</th>
                  <th>MQ-2 Gas Δ</th>
                  <th>Moisture</th>
                  <th>Prob / Model</th>
                  <th>Trainee</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredEvents.map((ev) => (
                  <tr key={ev.id || `${ev.device_id}-${ev.server_timestamp}`}>
                    <td style={{ fontFamily: 'var(--font-mono)', fontSize: 12, whiteSpace: 'nowrap' }}>
                      {new Date(ev.server_timestamp).toLocaleTimeString()}
                    </td>
                    <td>
                      <Link to={`/devices/${ev.device_id}`} className="hg-code" style={{ textDecoration: 'none' }}>
                        {ev.device_id}
                      </Link>
                    </td>
                    <td>
                      {ev.alert === 'DANGER' ? (
                        <span className="hg-badge hg-badge-danger">CRITICAL</span>
                      ) : ev.alert === 'CAUTION' ? (
                        <span className="hg-badge hg-badge-caution">CAUTION</span>
                      ) : (
                        <span className="hg-badge hg-badge-ok">NORMAL</span>
                      )}
                    </td>
                    <td style={{ fontFamily: 'var(--font-mono)' }}>
                      {ev.rms != null ? `${ev.rms} cts` : '—'}
                    </td>
                    <td style={{ fontFamily: 'var(--font-mono)' }}>
                      {ev.gas_delta != null ? `+${ev.gas_delta}` : '—'}
                    </td>
                    <td>
                      {ev.wet === true ? (
                        <span className="hg-badge hg-badge-caution">WET</span>
                      ) : ev.wet === false ? (
                        <span className="hg-badge hg-badge-neutral">DRY</span>
                      ) : (
                        '—'
                      )}
                    </td>
                    <td style={{ fontFamily: 'var(--font-mono)', fontSize: 12 }}>
                      {ev.leak_probability != null ? `${(ev.leak_probability * 100).toFixed(0)}% ` : ''}
                      <span style={{ color: 'var(--color-warm-graphite)', fontSize: 11 }}>
                        {ev.model_label || '(rms)'}
                      </span>
                    </td>
                    <td>
                      <span style={{ fontSize: 12 }}>{ev.trainee_id || '—'}</span>
                    </td>
                    <td>
                      <button
                        className="hg-btn hg-btn-secondary"
                        style={{ padding: '2px 8px', fontSize: 11 }}
                        onClick={() => handleInspect(ev)}
                      >
                        Inspect
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* INSPECTION DRAWER / MODAL */}
      {inspectedEvent && inspectedInsight && (
        <div className="hg-modal-backdrop" onClick={() => setInspectedEvent(null)}>
          <div
            className="hg-modal"
            style={{ maxWidth: 640 }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="hg-modal-header">
              <div>
                <h3 className="hg-modal-title">Diagnostic Telemetry Detail</h3>
                <p style={{ fontSize: 11, color: 'var(--color-warm-graphite)', fontFamily: 'var(--font-mono)' }}>
                  Device: {inspectedEvent.device_id} · Timestamp: {new Date(inspectedEvent.server_timestamp).toISOString()}
                </p>
              </div>
              <button
                className="hg-btn hg-btn-secondary"
                style={{ padding: '4px 8px' }}
                onClick={() => setInspectedEvent(null)}
              >
                ✕
              </button>
            </div>

            <div className="hg-modal-body" style={{ maxHeight: '70vh', overflowY: 'auto' }}>
              {/* Headline */}
              <div
                style={{
                  padding: '12px 16px',
                  background: 'var(--color-ivory)',
                  borderRadius: 6,
                  marginBottom: 16,
                  borderLeft: '4px solid var(--color-burnt-orange)',
                }}
              >
                <div style={{ fontWeight: 700, fontSize: 14, color: 'var(--color-carbon)' }}>
                  {inspectedInsight.headline}
                </div>
                <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
                  Supporting Modality: <strong>{inspectedInsight.supportingSensor}</strong>
                </div>
                <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
                  Algorithm: <strong>{inspectedInsight.algorithmModel}</strong>
                </div>
              </div>

              {/* Rationale & Actions */}
              <div style={{ marginBottom: 16 }}>
                <h4 style={{ fontSize: 12, textTransform: 'uppercase', color: 'var(--color-warm-graphite)', marginBottom: 4 }}>
                  Diagnostic Rationale
                </h4>
                <p style={{ fontSize: 13, color: 'var(--color-carbon)', lineHeight: 1.5 }}>
                  {inspectedInsight.rationale}
                </p>
              </div>

              <div style={{ marginBottom: 16 }}>
                <h4 style={{ fontSize: 12, textTransform: 'uppercase', color: 'var(--color-warm-graphite)', marginBottom: 4 }}>
                  Actionable Inspection Directives
                </h4>
                <p style={{ fontSize: 13, color: 'var(--color-carbon)', lineHeight: 1.5 }}>
                  {inspectedInsight.remediationStep}
                </p>
              </div>

              <div
                style={{
                  padding: '10px 14px',
                  background: 'rgba(240, 120, 66, 0.08)',
                  borderRadius: 6,
                  marginBottom: 16,
                  fontSize: 12,
                  color: 'var(--color-dark-orange)',
                }}
              >
                <strong>Operational Safety Notice:</strong> {inspectedInsight.safetyCaveat}
              </div>

              {/* Raw Payload Section */}
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                  <h4 style={{ fontSize: 12, textTransform: 'uppercase', color: 'var(--color-warm-graphite)', margin: 0 }}>
                    Raw Telemetry Payload (RFC JSON)
                  </h4>
                  <button
                    className="hg-btn hg-btn-secondary"
                    style={{ padding: '2px 8px', fontSize: 11 }}
                    onClick={copyInspectedPayload}
                  >
                    {copiedPayload ? '✓ Copied' : 'Copy JSON'}
                  </button>
                </div>
                <pre
                  style={{
                    background: 'var(--color-charcoal)',
                    color: '#e2e8f0',
                    padding: 12,
                    borderRadius: 6,
                    fontSize: 11,
                    fontFamily: 'var(--font-mono)',
                    overflowX: 'auto',
                    maxHeight: 200,
                  }}
                >
                  {JSON.stringify(inspectedEvent, null, 2)}
                </pre>
              </div>
            </div>

            <div className="hg-modal-footer">
              <Link
                to={`/devices/${inspectedEvent.device_id}`}
                className="hg-btn hg-btn-secondary"
                style={{ textDecoration: 'none' }}
              >
                View Device Rig
              </Link>
              {inspectedEvent.session_id > 0 && (
                <Link
                  to="/sessions"
                  className="hg-btn hg-btn-secondary"
                  style={{ textDecoration: 'none' }}
                >
                  Go to Session #{inspectedEvent.session_id}
                </Link>
              )}
              <button
                className="hg-btn hg-btn-primary"
                onClick={() => setInspectedEvent(null)}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
