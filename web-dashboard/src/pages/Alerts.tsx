import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { apiClient } from '../api/client';
import { useDemo } from '../context/DemoContext';
import type { PaginatedResponse, DashboardAlert } from '../types';

export default function Alerts() {
  const { isDemoMode, demoData } = useDemo();

  const [alerts, setAlerts] = useState<PaginatedResponse<DashboardAlert> | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');
  const [page, setPage] = useState<number>(1);
  const [filterType, setFilterType] = useState<string>('');
  const [filterDevice, setFilterDevice] = useState<string>('');

  const loadAlerts = useCallback(async () => {
    try {
      setIsLoading(true);
      setError('');

      if (isDemoMode) {
        let items: DashboardAlert[] = demoData.events
          .filter((e) => e.alert === 'DANGER' || e.alert === 'CAUTION')
          .map((e) => ({
            id: e.id,
            device_id: e.device_id,
            trainee_id: e.trainee_id,
            timestamp: e.server_timestamp,
            alert: e.alert || 'CAUTION',
            cause: e.cause || 'acoustic_elevation',
            details: {
              event_name: e.event_name || 'hazard_alert',
              model_label: e.model_label || 'rms_threshold',
              leak_probability: e.leak_probability ?? undefined,
              rms: e.rms ?? undefined,
              gas_delta: e.gas_delta ?? undefined,
            },
          }));

        if (filterType) {
          items = items.filter((a) => a.alert === filterType);
        }
        if (filterDevice) {
          items = items.filter((a) => a.device_id.toLowerCase().includes(filterDevice.toLowerCase()));
        }

        setAlerts({
          total: items.length,
          page,
          page_size: 50,
          items,
        });
        setIsLoading(false);
        return;
      }

      const params: any = { page, page_size: 50 };
      if (filterType) params.alert_type = filterType;
      if (filterDevice) params.device_id = filterDevice;
      const data = await apiClient.getDashboardAlerts(params);
      setAlerts(data);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load alerts');
    } finally {
      setIsLoading(false);
    }
  }, [isDemoMode, demoData.events, page, filterType, filterDevice]);

  useEffect(() => {
    loadAlerts();
  }, [loadAlerts]);

  const formatTimestamp = (timestamp: string) => {
    return new Date(timestamp).toLocaleString();
  };

  const alertBadge = (level: string) => {
    switch (level) {
      case 'DANGER':
        return <span className="hg-badge hg-badge-danger">⚠ {level}</span>;
      case 'CAUTION':
        return <span className="hg-badge hg-badge-caution">△ {level}</span>;
      default:
        return <span className="hg-badge hg-badge-neutral">{level}</span>;
    }
  };

  return (
    <div>
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">Hazard Alerts</h1>
          <p className="hg-page-subtitle">Recorded threshold breaches &amp; safety-critical diagnostic events</p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <Link to="/diagnostics" className="hg-btn hg-btn-primary" style={{ textDecoration: 'none' }}>
            Open Diagnostic Workspace →
          </Link>
          <button className="hg-btn hg-btn-secondary" onClick={loadAlerts}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
              <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            Refresh
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="hg-card" style={{ marginBottom: 20, padding: '16px 20px' }}>
        <div className="hg-filters" style={{ margin: 0 }}>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', width: '100%' }}>
            <div style={{ flex: '0 0 180px' }}>
              <label className="hg-label">Severity Level</label>
              <select
                className="hg-input"
                value={filterType}
                onChange={(e) => {
                  setFilterType(e.target.value);
                  setPage(1);
                }}
              >
                <option value="">All severities</option>
                <option value="DANGER">Critical (DANGER)</option>
                <option value="CAUTION">Warning (CAUTION)</option>
              </select>
            </div>
            <div style={{ flex: 1, minWidth: 200 }}>
              <label className="hg-label">Device ID</label>
              <input
                type="text"
                className="hg-input"
                placeholder="Filter by device ID…"
                value={filterDevice}
                onChange={(e) => {
                  setFilterDevice(e.target.value);
                  setPage(1);
                }}
              />
            </div>
          </div>
        </div>
      </div>

      {/* Loading */}
      {isLoading && (
        <div className="hg-loading-screen">
          <div className="hg-spinner" />
          <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>Loading alerts…</span>
        </div>
      )}

      {/* Error */}
      {error && !isLoading && (
        <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>
          {error}
        </div>
      )}

      {/* Empty */}
      {!isLoading && !error && alerts && alerts.items.length === 0 && (
        <div className="hg-card">
          <div className="hg-empty">
            <div className="hg-empty-icon">🛡</div>
            <p className="hg-empty-title">No alerts recorded</p>
            <p className="hg-empty-desc">All clear — no hazard events match the current filters.</p>
          </div>
        </div>
      )}

      {/* Table */}
      {!isLoading && alerts && alerts.items.length > 0 && (
        <div className="hg-card" style={{ padding: 0, overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table className="hg-table">
              <thead>
                <tr>
                  <th>Timestamp</th>
                  <th>Device ID</th>
                  <th>Trainee ID</th>
                  <th>Severity</th>
                  <th>Cause</th>
                  <th>Diagnostic Event</th>
                  <th>Key Telemetry Details</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {alerts.items.map((alert) => (
                  <tr key={alert.id}>
                    <td>
                      <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--color-warm-graphite)' }}>
                        {formatTimestamp(alert.timestamp)}
                      </span>
                    </td>
                    <td>
                      <span className="hg-code">{alert.device_id}</span>
                    </td>
                    <td>
                      <strong>{alert.trainee_id}</strong>
                    </td>
                    <td>{alertBadge(alert.alert)}</td>
                    <td>
                      <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, fontWeight: 500 }}>
                        {alert.cause || '—'}
                      </span>
                    </td>
                    <td style={{ fontSize: 12, color: 'var(--color-carbon)' }}>
                      {alert.details?.event_name || '—'}
                    </td>
                    <td>
                      <div style={{ fontSize: 11, fontFamily: 'var(--font-mono)', color: 'var(--color-warm-graphite)' }}>
                        {alert.details?.rms != null && (
                          <span style={{ marginRight: 8 }}>
                            RMS: <strong>{alert.details.rms.toFixed(1)}</strong>
                          </span>
                        )}
                        {alert.details?.leak_probability != null && (
                          <span style={{ marginRight: 8 }}>
                            Leak P: <strong>{(alert.details.leak_probability * 100).toFixed(0)}%</strong>
                          </span>
                        )}
                        {alert.details?.gas_delta != null && (
                          <span>
                            Gas Δ: <strong>+{alert.details.gas_delta}</strong>
                          </span>
                        )}
                      </div>
                    </td>
                    <td>
                      <Link
                        to="/diagnostics"
                        className="hg-btn hg-btn-secondary"
                        style={{ padding: '3px 8px', fontSize: 11, textDecoration: 'none' }}
                      >
                        Inspect
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
