import { useState, useEffect } from 'react';
import { apiClient } from '../api/client';
import type { PaginatedResponse, DashboardAlert } from '../types';

function Alerts() {
  const [alerts, setAlerts] = useState<PaginatedResponse<DashboardAlert> | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [filterType, setFilterType] = useState<string>('');
  const [filterDevice, setFilterDevice] = useState<string>('');

  useEffect(() => {
    loadAlerts();
  }, [page, filterType, filterDevice]);

  const loadAlerts = async () => {
    try {
      setIsLoading(true);
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
  };

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
          <p className="hg-page-subtitle">Recorded hazard &amp; diagnostic events from all devices</p>
        </div>
        <button className="hg-btn hg-btn-secondary" onClick={loadAlerts}>
          <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
            <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
            <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          Refresh
        </button>
      </div>

      {/* Filters */}
      <div className="hg-card" style={{ marginBottom: 20, padding: '16px 20px' }}>
        <div className="hg-filters" style={{ margin: 0 }}>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', width: '100%' }}>
            <div style={{ flex: '0 0 180px' }}>
              <label className="hg-label">Severity</label>
              <select
                className="hg-input"
                value={filterType}
                onChange={(e) => { setFilterType(e.target.value); setPage(1); }}
              >
                <option value="">All severities</option>
                <option value="DANGER">DANGER</option>
                <option value="CAUTION">CAUTION</option>
              </select>
            </div>
            <div style={{ flex: 1, minWidth: 200 }}>
              <label className="hg-label">Device ID</label>
              <input
                type="text"
                className="hg-input"
                placeholder="Filter by device ID…"
                value={filterDevice}
                onChange={(e) => { setFilterDevice(e.target.value); setPage(1); }}
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
                  <th>Event</th>
                  <th>Details</th>
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
                      <code className="hg-code">{alert.device_id}</code>
                    </td>
                    <td>
                      <span style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
                        {alert.trainee_id || '—'}
                      </span>
                    </td>
                    <td>{alertBadge(alert.alert)}</td>
                    <td style={{ fontSize: 12 }}>{alert.cause || '—'}</td>
                    <td style={{ fontSize: 12 }}>{alert.details.event_name || '—'}</td>
                    <td>
                      <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', fontFamily: 'var(--font-mono)', lineHeight: 1.8 }}>
                        {alert.details.leak_probability != null && (
                          <div>Leak P: <strong style={{ color: 'var(--color-carbon)' }}>
                            {(alert.details.leak_probability * 100).toFixed(1)}%
                          </strong></div>
                        )}
                        {alert.details.rms != null && (
                          <div>RMS: <strong style={{ color: 'var(--color-carbon)' }}>
                            {alert.details.rms.toFixed(2)}
                          </strong></div>
                        )}
                        {alert.details.gas_delta != null && (
                          <div>Gas Δ: <strong style={{ color: 'var(--color-carbon)' }}>
                            {alert.details.gas_delta.toFixed(1)}
                          </strong></div>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {alerts.total > alerts.page_size && (
            <div className="hg-pagination" style={{ padding: '12px 20px' }}>
              <span style={{ fontSize: 13, color: 'var(--color-warm-graphite)' }}>
                Showing {((page - 1) * alerts.page_size) + 1}–
                {Math.min(page * alerts.page_size, alerts.total)} of&nbsp;
                <strong>{alerts.total}</strong> alerts
              </span>
              <div style={{ display: 'flex', gap: 6 }}>
                <button
                  className="hg-btn hg-btn-secondary"
                  onClick={() => setPage(Math.max(1, page - 1))}
                  disabled={page === 1}
                  style={{ padding: '6px 12px' }}
                >
                  ← Prev
                </button>
                <button
                  className="hg-btn hg-btn-secondary"
                  onClick={() => setPage(page + 1)}
                  disabled={page * alerts.page_size >= alerts.total}
                  style={{ padding: '6px 12px' }}
                >
                  Next →
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default Alerts;
