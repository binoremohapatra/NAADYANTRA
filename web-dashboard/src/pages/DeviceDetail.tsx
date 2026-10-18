import { useState, useEffect, useCallback } from 'react';
import { useParams, Link } from 'react-router-dom';
import { apiClient } from '../api/client';
import { useDemo } from '../context/DemoContext';
import type { Device, DeviceStatus, LatestTelemetryResponse, Event } from '../types';

function MetricBlock({
  label,
  value,
  unit,
  accent,
  subtext,
}: {
  label: string;
  value: string | React.ReactNode;
  unit?: string;
  accent?: string;
  subtext?: string;
}) {
  return (
    <div
      style={{
        background: 'var(--color-ivory)',
        border: '1px solid var(--color-warm-stone)',
        borderRadius: 8,
        padding: '14px 16px',
      }}
    >
      <div
        style={{
          fontSize: 10,
          fontWeight: 700,
          letterSpacing: '0.06em',
          textTransform: 'uppercase',
          color: 'var(--color-warm-graphite)',
          marginBottom: 6,
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontSize: 20,
          fontWeight: 800,
          color: accent || 'var(--color-carbon)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '-0.01em',
        }}
      >
        {value}
        {unit && (
          <span style={{ fontSize: 11, fontWeight: 500, color: 'var(--color-warm-graphite)', marginLeft: 4 }}>
            {unit}
          </span>
        )}
      </div>
      {subtext && <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', marginTop: 4 }}>{subtext}</div>}
    </div>
  );
}

export default function DeviceDetail() {
  const { deviceId } = useParams<{ deviceId: string }>();
  const { isDemoMode, demoData } = useDemo();

  const [device, setDevice] = useState<Device | null>(null);
  const [status, setStatus] = useState<DeviceStatus | null>(null);
  const [telemetry, setTelemetry] = useState<LatestTelemetryResponse | null>(null);
  const [events, setEvents] = useState<Event[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');

  const [isRotatingKey, setIsRotatingKey] = useState<boolean>(false);
  const [issuedKey, setIssuedKey] = useState<string | null>(null);
  const [rotationMessage, setRotationMessage] = useState<string>('');
  const [isCopied, setIsCopied] = useState<boolean>(false);

  const fetchLatestTelemetry = useCallback(
    async (id: string) => {
      try {
        if (isDemoMode) {
          setTelemetry(demoData.latestTelemetry[id] || null);
          return;
        }
        const tel = await apiClient.getLatestTelemetry(id);
        setTelemetry(tel);
      } catch {
        // keep existing on transient poll failure
      }
    },
    [isDemoMode, demoData.latestTelemetry]
  );

  const loadDeviceData = useCallback(async () => {
    if (!deviceId) return;
    try {
      setIsLoading(true);
      setError('');

      if (isDemoMode) {
        const d = demoData.devices.find((dev) => dev.device_id === deviceId) || demoData.devices[0];
        const s = demoData.deviceStatuses[deviceId] || demoData.deviceStatuses['SIH-DEV-01'];
        const tel = demoData.latestTelemetry[deviceId] || demoData.latestTelemetry['SIH-DEV-01'];
        const evs = demoData.events.filter((e) => e.device_id === deviceId);

        setDevice(d);
        setStatus(s);
        setTelemetry(tel);
        setEvents(evs.length > 0 ? evs : demoData.events.slice(0, 5));
        setIsLoading(false);
        return;
      }

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
  }, [deviceId, isDemoMode, demoData]);

  useEffect(() => {
    if (deviceId) loadDeviceData();
  }, [deviceId, loadDeviceData]);

  useEffect(() => {
    if (!deviceId) return;
    const interval = setInterval(() => fetchLatestTelemetry(deviceId), 5000);
    return () => clearInterval(interval);
  }, [deviceId, fetchLatestTelemetry]);

  const handleRotateKey = async () => {
    if (!deviceId) return;
    if (!confirm('Rotate credential for this device? The old key will be immediately revoked.')) return;
    try {
      setIsRotatingKey(true);
      if (isDemoMode) {
        setIssuedKey('sih_demo_key_' + Math.random().toString(36).substring(2, 12));
        setRotationMessage('Simulated device key rotated successfully. Store this key in firmware credentials.h.');
        return;
      }
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
      if (!isDemoMode) {
        await apiClient.deactivateDevice(deviceId);
      }
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

  const fmt = (ts?: string | null) => (ts ? new Date(ts).toLocaleString() : '—');
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

  if (error && !device) {
    return (
      <div className="hg-alert hg-alert-error" style={{ maxWidth: 480 }}>
        {error}
      </div>
    );
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
            display: 'flex',
            alignItems: 'center',
            gap: 6,
            fontSize: 13,
            color: 'var(--color-burnt-orange)',
            textDecoration: 'none',
            fontWeight: 500,
          }}
        >
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M9 2L4 7l5 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          Device Inventory
        </Link>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="hg-btn hg-btn-secondary" onClick={loadDeviceData} style={{ fontSize: 12 }}>
            Refresh
          </button>
          <button
            className="hg-btn hg-btn-primary"
            onClick={handleRotateKey}
            disabled={isRotatingKey}
            style={{ fontSize: 12 }}
          >
            {isRotatingKey ? (
              <>
                <span className="hg-spinner" style={{ width: 12, height: 12, borderWidth: 2 }} /> Rotating…
              </>
            ) : (
              'Rotate Credential'
            )}
          </button>
          {device.is_active && (
            <button className="hg-btn hg-btn-danger" onClick={handleDeactivate} style={{ fontSize: 12 }}>
              Deactivate
            </button>
          )}
        </div>
      </div>

      {/* Device Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
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
        {!device.is_active && <span className="hg-badge hg-badge-danger">Deactivated</span>}
        {device.name && (
          <span style={{ fontSize: 14, color: 'var(--color-warm-graphite)', fontWeight: 500 }}>
            {device.name}
          </span>
        )}
      </div>

      {/* Hardware Sensor Modality & Validation Matrix */}
      <div className="hg-card" style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 12 }}>
          Hardware Sensor Modality &amp; Firmware Configuration (FW {device.firmware_version || '1.1.0'})
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 10 }}>
          <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 11, fontWeight: 700 }}>Contact Acoustic Piezo</span>
              <span className="hg-state-badge hg-state-normal" style={{ fontSize: 9 }}>ACTIVE</span>
            </div>
            <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
              ADC1_CH3 · Localized vibration amplitude (counts).
            </div>
          </div>

          <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 11, fontWeight: 700 }}>MQ-2 Combustible Gas</span>
              <span className="hg-state-badge hg-state-warning" style={{ fontSize: 9 }}>INDICATIVE</span>
            </div>
            <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
              ADC1_CH4 · Relative ADC delta. Uncalibrated screening.
            </div>
          </div>

          <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 11, fontWeight: 700 }}>Moisture Conduction Probe</span>
              <span className="hg-state-badge hg-state-normal" style={{ fontSize: 9 }}>ACTIVE</span>
            </div>
            <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
              ADC1_CH5 · Gated excitation on PIN_MOIST_PWR.
            </div>
          </div>

          <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px dashed var(--color-warm-stone)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--color-warm-graphite)' }}>MLX90614 Contactless IR</span>
              <span className="hg-state-badge hg-state-disabled" style={{ fontSize: 9 }}>DISABLED</span>
            </div>
            <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
              HAS_HEAT_SENSOR 0 in firmware source.
            </div>
          </div>

          <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px dashed var(--color-warm-stone)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--color-warm-graphite)' }}>GUVA-S12SD UV Sensor</span>
              <span className="hg-state-badge hg-state-disabled" style={{ fontSize: 9 }}>DISABLED</span>
            </div>
            <div style={{ fontSize: 10, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
              HAS_UV_SENSOR 0 in firmware source.
            </div>
          </div>
        </div>
      </div>

      {/* Live Telemetry Card */}
      <div className="hg-card" style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
          <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-carbon)' }}>
            Latest Ingested Telemetry
          </div>
          {telemetry && (
            <span
              className={`hg-badge ${
                !telemetry.has_data ? 'hg-badge-neutral' : telemetry.is_stale ? 'hg-badge-caution' : 'hg-badge-ok'
              }`}
            >
              {!telemetry.has_data
                ? 'No telemetry'
                : telemetry.is_stale
                ? `Stale · ${telemetry.staleness_seconds}s ago`
                : `Live · ${telemetry.staleness_seconds}s ago`}
            </span>
          )}
        </div>

        {ev ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 10 }}>
            <MetricBlock
              label="Acoustic RMS"
              value={ev.rms != null ? ev.rms.toFixed(1) : '—'}
              unit="counts"
              subtext="Contact Piezo 12-bit ADC"
            />
            <MetricBlock
              label="Leak Prob. (Heuristic)"
              value={ev.leak_probability != null ? `${(ev.leak_probability * 100).toFixed(0)}%` : '—'}
              subtext="Ratio: (RMS/RMS_base)/4"
              accent={ev.leak_probability && ev.leak_probability >= 0.75 ? 'var(--color-alert-danger)' : undefined}
            />
            <MetricBlock
              label="Gas Δ (ADC)"
              value={ev.gas_delta != null ? String(ev.gas_delta) : '—'}
              unit="Δ counts"
              subtext="Uncalibrated MQ-2 delta"
            />
            <MetricBlock
              label="Gas Ratio Rs/R0"
              value={ev.gas_ratio != null ? ev.gas_ratio.toFixed(3) : '—'}
              subtext="Indicative ratio only"
            />
            <MetricBlock
              label="Moisture Conduction"
              value={ev.wet === true ? 'WET' : ev.wet === false ? 'DRY' : '—'}
              accent={ev.wet === true ? 'var(--color-alert-danger)' : ev.wet === false ? 'var(--color-alert-ok)' : undefined}
              subtext="Gated conduction pin"
            />
            <MetricBlock
              label="Alert Classification"
              value={ev.alert || 'NORMAL'}
              accent={alertColor(ev.alert)}
              subtext={`Cause: ${ev.cause || 'ambient'}`}
            />
            <MetricBlock
              label="Device Uptime"
              value={ev.device_uptime_ms != null ? `${(ev.device_uptime_ms / 1000).toFixed(0)}s` : '—'}
              subtext="FreeRTOS boot elapsed"
            />
          </div>
        ) : (
          <div style={{ padding: 24, textAlign: 'center', color: 'var(--color-warm-graphite)', fontSize: 13 }}>
            Awaiting first telemetry event from device…
          </div>
        )}
      </div>

      {/* Recent Observations Table */}
      <div className="hg-card" style={{ padding: 0, overflow: 'hidden', marginBottom: 20 }}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--color-warm-stone)', fontWeight: 700, fontSize: 13 }}>
          Recent Telemetry Ingestions for {device.device_id}
        </div>
        <div style={{ overflowX: 'auto' }}>
          <table className="hg-table">
            <thead>
              <tr>
                <th>Timestamp</th>
                <th>Event / Cause</th>
                <th>Alert</th>
                <th>Acoustic RMS</th>
                <th>Gas Delta</th>
                <th>Moisture</th>
                <th>Model Label</th>
              </tr>
            </thead>
            <tbody>
              {events.map((e) => (
                <tr key={e.id}>
                  <td style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--color-warm-graphite)', whiteSpace: 'nowrap' }}>
                    {fmt(e.server_timestamp)}
                  </td>
                  <td>
                    <strong>{e.event_name || 'telemetry'}</strong>
                    {e.cause && <span style={{ display: 'block', fontSize: 11, color: 'var(--color-warm-graphite)' }}>{e.cause}</span>}
                  </td>
                  <td>
                    <span
                      className={`hg-badge ${
                        e.alert === 'DANGER'
                          ? 'hg-badge-danger'
                          : e.alert === 'CAUTION'
                          ? 'hg-badge-caution'
                          : 'hg-badge-ok'
                      }`}
                    >
                      {e.alert || 'NORMAL'}
                    </span>
                  </td>
                  <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 600 }}>
                    {e.rms != null ? `${e.rms.toFixed(1)} counts` : '—'}
                  </td>
                  <td style={{ fontFamily: 'var(--font-mono)' }}>
                    {e.gas_delta != null ? `+${e.gas_delta}` : '—'}
                  </td>
                  <td>
                    {e.wet === true ? (
                      <span className="hg-badge hg-badge-danger">WET</span>
                    ) : e.wet === false ? (
                      <span className="hg-badge hg-badge-ok">DRY</span>
                    ) : (
                      '—'
                    )}
                  </td>
                  <td style={{ fontSize: 11, color: 'var(--color-warm-graphite)' }}>{e.model_label || 'heuristic'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Key Rotation Success Dialog */}
      {issuedKey && (
        <div className="hg-modal-backdrop" onClick={() => setIssuedKey(null)}>
          <div className="hg-modal" style={{ maxWidth: 480 }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <h3 style={{ fontSize: 16, margin: 0 }}>New Device Credential Issued</h3>
              <button className="hg-close-btn" onClick={() => setIssuedKey(null)}>×</button>
            </div>
            <p style={{ fontSize: 13, color: 'var(--color-carbon)', marginBottom: 16 }}>{rotationMessage}</p>
            <div
              style={{
                background: 'var(--color-ivory)',
                padding: '12px 14px',
                borderRadius: 6,
                border: '1px solid var(--color-warm-stone)',
                fontFamily: 'var(--font-mono)',
                fontSize: 13,
                wordBreak: 'break-all',
                color: 'var(--color-burnt-orange)',
                fontWeight: 700,
                marginBottom: 16,
              }}
            >
              {issuedKey}
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <button className="hg-btn hg-btn-primary" onClick={() => copyToClipboard(issuedKey)}>
                {isCopied ? 'Copied to Clipboard!' : 'Copy Key'}
              </button>
              <button className="hg-btn hg-btn-secondary" onClick={() => setIssuedKey(null)}>
                Dismiss
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
