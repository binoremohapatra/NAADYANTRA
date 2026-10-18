import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { apiClient } from '../api/client';
import type { Device, DeviceStatus, LatestTelemetryResponse, Event } from '../types';

function MetricBlock({ label, value, unit, accent }: {
  label: string;
  value: string | React.ReactNode;
  unit?: string;
  accent?: string;
}) {
  return (
    <div style={{
      background: 'var(--color-ivory)',
      border: '1px solid var(--color-warm-stone)',
      borderRadius: 8,
      padding: '14px 16px',
    }}>
      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.06em', textTransform: 'uppercase', color: 'var(--color-warm-graphite)', marginBottom: 6 }}>
        {label}
      </div>
      <div style={{ fontSize: 20, fontWeight: 800, color: accent || 'var(--color-carbon)', fontFamily: 'var(--font-mono)', letterSpacing: '-0.01em' }}>
        {value}
        {unit && <span style={{ fontSize: 11, fontWeight: 500, color: 'var(--color-warm-graphite)', marginLeft: 4 }}>{unit}</span>}
      </div>
    </div>
  );
}

function DeviceDetail() {
  const { deviceId } = useParams<{ deviceId: string }>();

  const [device, setDevice] = useState<Device | null>(null);
  const [status, setStatus] = useState<DeviceStatus | null>(null);
  const [telemetry, setTelemetry] = useState<LatestTelemetryResponse | null>(null);
  const [events, setEvents] = useState<Event[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  const [isRotatingKey, setIsRotatingKey] = useState(false);
  const [issuedKey, setIssuedKey] = useState<string | null>(null);
  const [rotationMessage, setRotationMessage] = useState('');
  const [isCopied, setIsCopied] = useState(false);

  useEffect(() => {
    if (deviceId) loadDeviceData();
  }, [deviceId]);

  useEffect(() => {
    if (!deviceId) return;
    const interval = setInterval(() => fetchLatestTelemetry(deviceId), 5000);
    return () => clearInterval(interval);
  }, [deviceId]);

  const fetchLatestTelemetry = async (id: string) => {
    try {
      const tel = await apiClient.getLatestTelemetry(id);
      setTelemetry(tel);
    } catch {
      // keep existing on transient poll failure
    }
  };

  const loadDeviceData = async () => {
    if (!deviceId) return;
    try {
      setIsLoading(true);
      setError('');
      const [deviceData, statusData, eventsData, telemetryData] = await Promise.all([
        apiClient.getDevice(deviceId),
        apiClient.getDeviceStatus(deviceId),
        apiClient.getDeviceEvents({ device_id: deviceId, page_size: 15 }),
        apiClient.getLatestTelemetry(deviceId),
      ]);
      setDevice(deviceData);
      setStatus(statusData);
      setEvents(eventsData.items || []);
      setTelemetry(telemetryData);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load device data');
    } finally {
      setIsLoading(false);
    }
  };

  const handleRotateKey = async () => {
    if (!deviceId) return;
    if (!confirm('Rotate credential for this device? The old key will be immediately revoked.')) return;
    try {
      setIsRotatingKey(true);
      const res = await apiClient.rotateDeviceKey(deviceId);
      setIssuedKey(res.device_key);
      setRotationMessage(res.message);
    } catch (err: any) {
      alert(err.response?.data?.detail || 'Failed to rotate key');
    } finally {
      setIsRotatingKey(false);
    }
  };

  const handleDeactivate = async () => {
    if (!deviceId) return;
    if (!confirm('Deactivate this device? It will no longer be permitted to ingest telemetry.')) return;
    try {
      await apiClient.deactivateDevice(deviceId);
      await loadDeviceData();
    } catch (err: any) {
      alert(err.response?.data?.detail || 'Failed to deactivate device');
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setIsCopied(true);
    setTimeout(() => setIsCopied(false), 2000);
  };

  const fmt = (ts?: string | null) => ts ? new Date(ts).toLocaleString() : '—';
  const alertColor = (level: string | null) => {
    if (level === 'DANGER') return 'var(--color-alert-danger)';
    if (level === 'CAUTION') return 'var(--color-alert-caution)';
    return 'var(--color-alert-ok)';
  };

  if (isLoading) {
    return (
      <div className="hg-loading-screen">
        <div className="hg-spinner" />
        <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>Loading device details…</span>
      </div>
    );
  }

  if (error) {
    return <div className="hg-alert hg-alert-error" style={{ maxWidth: 480 }}>{error}</div>;
  }

  if (!device || !status) {
    return (
      <div className="hg-empty">
        <div className="hg-empty-icon">📡</div>
        <p className="hg-empty-title">Device not found</p>
      </div>
    );
  }

  const ev = telemetry?.event;

  return (
    <div>
      {/* Breadcrumb + Actions */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
        <Link
          to="/devices"
          style={{
            display: 'flex', alignItems: 'center', gap: 6, fontSize: 13,
            color: 'var(--color-burnt-orange)', textDecoration: 'none', fontWeight: 500,
          }}
        >
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M9 2L4 7l5 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          Device Inventory
        </Link>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="hg-btn hg-btn-secondary" onClick={loadDeviceData} style={{ fontSize: 12 }}>Refresh</button>
          <button
            className="hg-btn hg-btn-primary"
            onClick={handleRotateKey}
            disabled={isRotatingKey}
            style={{ fontSize: 12 }}
          >
            {isRotatingKey ? <><span className="hg-spinner" style={{ width: 12, height: 12, borderWidth: 2 }} /> Rotating…</> : 'Rotate Credential'}
          </button>
          {device.is_active && (
            <button className="hg-btn hg-btn-danger" onClick={handleDeactivate} style={{ fontSize: 12 }}>
              Deactivate
            </button>
          )}
        </div>
      </div>

      {/* Device Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 24 }}>
        <h1 className="hg-page-title" style={{ margin: 0 }}>
          <code style={{ fontFamily: 'var(--font-mono)', fontSize: 22 }}>{device.device_id}</code>
        </h1>
        {status.is_online ? (
          <span className="hg-badge hg-badge-ok">
            <span className="hg-dot hg-dot-ok hg-dot-pulse" style={{ width: 6, height: 6 }} />
            Online
          </span>
        ) : (
          <span className="hg-badge hg-badge-neutral">Offline</span>
        )}
        {!device.is_active && (
          <span className="hg-badge hg-badge-danger">Deactivated</span>
        )}
        {device.name && (
          <span style={{ fontSize: 14, color: 'var(--color-warm-graphite)', fontWeight: 500 }}>
            {device.name}
          </span>
        )}
      </div>

      {/* Live Telemetry */}
      <div className="hg-card" style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
          <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-carbon)' }}>
            Live Ingested Telemetry
          </div>
          {telemetry && (
            <span className={`hg-badge ${!telemetry.has_data ? 'hg-badge-neutral' : telemetry.is_stale ? 'hg-badge-caution' : 'hg-badge-ok'}`}>
              {!telemetry.has_data
                ? 'No telemetry'
                : telemetry.is_stale
                ? `Stale · ${telemetry.staleness_seconds}s ago`
                : `Live · ${telemetry.staleness_seconds}s ago`}
            </span>
          )}
        </div>

        {ev ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 10 }}>
            <MetricBlock label="Acoustic RMS" value={ev.rms != null ? ev.rms.toFixed(1) : '—'} unit="counts" />
            <MetricBlock label="Gas Δ (ADC)" value={ev.gas_delta != null ? String(ev.gas_delta) : '—'} unit="Δ cts" />
            <MetricBlock label="Gas Ratio Rs/R0" value={ev.gas_ratio != null ? ev.gas_ratio.toFixed(3) : '—'} />
            <MetricBlock
              label="Moisture"
              value={ev.wet === true ? 'WET' : ev.wet === false ? 'DRY' : '—'}
              accent={ev.wet === true ? 'var(--color-alert-danger)' : ev.wet === false ? 'var(--color-alert-ok)' : undefined}
            />
            <MetricBlock label="Temperature" value={ev.temperature != null ? `${ev.temperature}°C` : '—'} />
            <MetricBlock label="UV Delta" value={ev.uv_delta != null ? String(ev.uv_delta) : '—'} />
            <MetricBlock
              label="Alert Level"
              value={ev.alert || 'NORMAL'}
              accent={alertColor(ev.alert)}
            />
            <MetricBlock label="Cause" value={ev.cause || 'ambient'} />
            <MetricBlock
              label="ML Label"
              value={ev.model_label || '—'}
              accent={ev.model_label ? 'var(--color-burnt-orange)' : undefined}
            />
            <MetricBlock
              label="Leak P"
              value={ev.leak_probability != null ? `${(ev.leak_probability * 100).toFixed(1)}%` : '—'}
              accent={ev.leak_probability != null && ev.leak_probability > 0.5 ? 'var(--color-alert-danger)' : undefined}
            />
          </div>
        ) : (
          <div className="hg-empty" style={{ padding: '32px 16px' }}>
            <div className="hg-empty-icon">📡</div>
            <p className="hg-empty-title">Awaiting first telemetry</p>
            <p className="hg-empty-desc">No payload received from this device yet.</p>
          </div>
        )}
      </div>

      {/* Device Metadata */}
      <div className="hg-card" style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 14 }}>
          Device Metadata
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12, fontSize: 13 }}>
          {[
            { label: 'Name', value: device.name || '—' },
            { label: 'Firmware', value: device.firmware_version ? <code className="hg-code">{device.firmware_version}</code> : '—' },
            { label: 'Last Contact', value: fmt(status.last_seen_at) },
            { label: 'Last Telemetry', value: fmt(status.last_telemetry_at) },
            { label: 'Registered At', value: fmt(device.created_at) },
            { label: '24h Event Count', value: `${status.recent_activity_count} events` },
          ].map(({ label, value }) => (
            <div key={label}>
              <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase', color: 'var(--color-warm-graphite)', marginBottom: 3 }}>
                {label}
              </div>
              <div style={{ fontWeight: 500, color: 'var(--color-carbon)' }}>{value}</div>
            </div>
          ))}
        </div>
        {status.last_error && (
          <div className="hg-alert hg-alert-error" style={{ marginTop: 12 }}>
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" style={{ flexShrink: 0 }}>
              <circle cx="7" cy="7" r="6" stroke="currentColor" strokeWidth="1.5"/>
              <path d="M7 4.5V7" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
              <circle cx="7" cy="9.5" r="0.7" fill="currentColor"/>
            </svg>
            <span><strong>Last ingestion error:</strong> {status.last_error}</span>
          </div>
        )}
      </div>

      {/* Event History */}
      <div className="hg-card" style={{ padding: 0, overflow: 'hidden' }}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--color-warm-stone)' }}>
          <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-carbon)' }}>
            Recent Event History <span style={{ fontSize: 12, fontWeight: 400, color: 'var(--color-warm-graphite)' }}>(last 15)</span>
          </div>
        </div>
        {events.length === 0 ? (
          <div className="hg-empty" style={{ padding: '32px 16px' }}>
            <p className="hg-empty-desc">No events recorded for this device.</p>
          </div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table className="hg-table">
              <thead>
                <tr>
                  <th>Time</th>
                  <th>Event</th>
                  <th>Alert</th>
                  <th>Cause</th>
                  <th>RMS</th>
                  <th>Gas Δ</th>
                  <th>Leak P</th>
                </tr>
              </thead>
              <tbody>
                {events.map((ev) => (
                  <tr key={ev.id}>
                    <td style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--color-warm-graphite)' }}>
                      {fmt(ev.server_timestamp)}
                    </td>
                    <td style={{ fontSize: 12, fontWeight: 500 }}>{ev.event_name || 'telemetry'}</td>
                    <td>
                      {ev.alert ? (
                        <span className={`hg-badge ${ev.alert === 'DANGER' ? 'hg-badge-danger' : ev.alert === 'CAUTION' ? 'hg-badge-caution' : 'hg-badge-ok'}`}>
                          {ev.alert}
                        </span>
                      ) : (
                        <span className="hg-badge hg-badge-ok">OK</span>
                      )}
                    </td>
                    <td style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>{ev.cause || '—'}</td>
                    <td style={{ fontFamily: 'var(--font-mono)', fontSize: 12 }}>{ev.rms != null ? ev.rms.toFixed(1) : '—'}</td>
                    <td style={{ fontFamily: 'var(--font-mono)', fontSize: 12 }}>{ev.gas_delta ?? '—'}</td>
                    <td style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: ev.leak_probability != null && ev.leak_probability > 0.5 ? 'var(--color-alert-danger)' : undefined }}>
                      {ev.leak_probability != null ? `${(ev.leak_probability * 100).toFixed(1)}%` : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* New Key Modal */}
      {issuedKey && (
        <div className="hg-modal-backdrop">
          <div className="hg-modal">
            <div className="hg-modal-header">
              <span className="hg-modal-title">New Credential Issued</span>
              <button className="hg-close-btn" onClick={() => setIssuedKey(null)}>×</button>
            </div>
            <div className="hg-modal-body">
              <p style={{ fontSize: 13, color: 'var(--color-warm-graphite)', marginBottom: 12 }}>
                {rotationMessage}
              </p>
              <div style={{
                background: 'var(--color-warm-stone)',
                border: '1px solid var(--color-soft-sand)',
                borderRadius: 8,
                padding: '14px 16px',
                fontFamily: 'var(--font-mono)',
                fontSize: 13,
                wordBreak: 'break-all',
                userSelect: 'all',
                color: 'var(--color-carbon)',
                marginBottom: 16,
              }}>
                {issuedKey}
              </div>
              <div className="hg-alert" style={{ background: '#fff7ed', border: '1px solid #fed7aa', color: '#c2410c', fontSize: 12 }}>
                ⚠ This key will only be shown once. Copy it before closing.
              </div>
            </div>
            <div className="hg-modal-footer">
              <button className="hg-btn hg-btn-secondary" onClick={() => setIssuedKey(null)}>Dismiss</button>
              <button className="hg-btn hg-btn-primary" onClick={() => copyToClipboard(issuedKey)}>
                {isCopied ? '✓ Copied!' : 'Copy to Clipboard'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default DeviceDetail;
