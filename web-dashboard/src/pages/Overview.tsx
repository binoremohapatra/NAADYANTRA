import { useState, useEffect } from 'react';
import { apiClient } from '../api/client';
import type { DashboardOverview } from '../types';

function Overview() {
  const [overview, setOverview] = useState<DashboardOverview | null>(null);
  const [activeAlertsCount, setActiveAlertsCount] = useState<number>(0);
  const [apiStatus, setApiStatus] = useState<'healthy' | 'disconnected' | 'unknown'>('unknown');
  const [dbStatus, setDbStatus] = useState<string>('unknown');
  const [serverUtc, setServerUtc] = useState<string>('');
  const [lastRefresh, setLastRefresh] = useState<Date | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    loadOverview();
    const interval = setInterval(loadOverview, 15000);
    return () => clearInterval(interval);
  }, []);

  const loadOverview = async () => {
    try {
      setError('');

      try {
        const ready = await apiClient.readyCheck();
        setApiStatus('healthy');
        setDbStatus(ready.database || 'connected');
      } catch {
        setApiStatus('disconnected');
        setDbStatus('error');
      }

      const data = await apiClient.getDashboardOverview();
      setOverview(data);
      if (data.server_utc) {
        setServerUtc(new Date(data.server_utc).toLocaleTimeString());
      }

      const alertsCount = await apiClient.getRecordedAlertsCount();
      setActiveAlertsCount(alertsCount);

      setLastRefresh(new Date());
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load operational overview');
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="hg-loading-screen">
        <div className="hg-spinner" />
        <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>
          Loading operational overview…
        </span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="hg-alert hg-alert-error" style={{ maxWidth: 480 }}>
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ flexShrink: 0 }}>
          <circle cx="8" cy="8" r="7" stroke="currentColor" strokeWidth="1.5"/>
          <path d="M8 5v3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
          <circle cx="8" cy="11" r="0.75" fill="currentColor"/>
        </svg>
        {error}
      </div>
    );
  }

  if (!overview) {
    return (
      <div className="hg-empty">
        <div className="hg-empty-icon">📡</div>
        <p className="hg-empty-title">No data available</p>
        <p className="hg-empty-desc">Backend is not returning overview data.</p>
      </div>
    );
  }

  const onlineCount = overview.online_devices_count ?? overview.active_devices_count;
  const offlineCount = overview.offline_devices_count ?? (overview.total_devices - overview.active_devices_count);

  return (
    <div>
      {/* Page header */}
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">Operational Overview</h1>
          <p className="hg-page-subtitle">
            Live telemetry, device connectivity &amp; training aggregation
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
          {/* Status pills */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            background: 'var(--color-white)',
            border: '1px solid var(--color-warm-stone)',
            borderRadius: 99,
            padding: '6px 14px',
            fontSize: 12,
          }}>
            <span className={`hg-dot ${apiStatus === 'healthy' ? 'hg-dot-ok hg-dot-pulse' : 'hg-dot-danger'}`} />
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              Backend&nbsp;
              <strong style={{ color: 'var(--color-carbon)' }}>
                {apiStatus === 'healthy' ? 'Healthy' : 'Offline'}
              </strong>
            </span>
            <span style={{ color: 'var(--color-warm-stone)' }}>|</span>
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              DB&nbsp;<strong style={{ color: 'var(--color-carbon)' }}>{dbStatus}</strong>
            </span>
          </div>

          {serverUtc && (
            <span style={{
              fontFamily: 'var(--font-mono)',
              fontSize: 11,
              color: 'var(--color-warm-graphite)',
              background: 'var(--color-white)',
              border: '1px solid var(--color-warm-stone)',
              borderRadius: 6,
              padding: '5px 10px',
            }}>
              {serverUtc} UTC
            </span>
          )}

          {lastRefresh && (
            <span style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
              Updated {lastRefresh.toLocaleTimeString()}
            </span>
          )}

          <button className="hg-btn hg-btn-secondary" onClick={loadOverview}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
              <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            Refresh
          </button>
        </div>
      </div>

      {/* Metric Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: 16,
        marginBottom: 24,
      }}>
        {/* Devices */}
        <div className="hg-metric-card accent-orange">
          <div className="hg-metric-label">Registered Devices</div>
          <div className="hg-metric-value">{overview.total_devices}</div>
          <div style={{ marginTop: 10, display: 'flex', justifyContent: 'space-between', fontSize: 12 }}>
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              Online&nbsp;<strong style={{ color: 'var(--color-alert-ok)' }}>{onlineCount}</strong>
            </span>
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              Offline&nbsp;<strong>{offlineCount}</strong>
            </span>
          </div>
        </div>

        {/* Telemetry freshness */}
        <div className="hg-metric-card accent-ok">
          <div className="hg-metric-label">Telemetry Freshness</div>
          <div className="hg-metric-value" style={{ color: 'var(--color-alert-ok)' }}>
            {onlineCount}
          </div>
          <div style={{ marginTop: 10, display: 'flex', justifyContent: 'space-between', fontSize: 12 }}>
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              Stale&nbsp;<strong style={{ color: 'var(--color-alert-caution)' }}>
                {overview.stale_devices_count ?? 0}
              </strong>
            </span>
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              No data&nbsp;<strong>{overview.never_reported_count ?? 0}</strong>
            </span>
          </div>
        </div>

        {/* Training sessions */}
        <div className="hg-metric-card accent-orange">
          <div className="hg-metric-label">Training Sessions</div>
          <div className="hg-metric-value">{overview.total_sessions}</div>
          <div style={{ marginTop: 10, display: 'flex', justifyContent: 'space-between', fontSize: 12 }}>
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              Last 24h&nbsp;<strong style={{ color: 'var(--color-burnt-orange)' }}>
                {overview.recent_sessions_count}
              </strong>
            </span>
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              Trainees&nbsp;<strong>{overview.total_trainees}</strong>
            </span>
          </div>
        </div>

        {/* Alerts */}
        <div className="hg-metric-card accent-danger">
          <div className="hg-metric-label">Recorded Hazard Alerts</div>
          <div className="hg-metric-value" style={{ color: 'var(--color-alert-danger)' }}>
            {activeAlertsCount}
          </div>
          <div style={{ marginTop: 10, display: 'flex', justifyContent: 'space-between', fontSize: 12 }}>
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              Total Events&nbsp;<strong>{overview.total_events}</strong>
            </span>
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              Failures&nbsp;<strong>{overview.recent_ingestion_failures_count ?? 0}</strong>
            </span>
          </div>
        </div>
      </div>

      {/* Status info */}
      <div className="hg-card">
        <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
          <div style={{
            width: 36,
            height: 36,
            borderRadius: 8,
            background: 'rgba(240,120,66,0.1)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <circle cx="8" cy="8" r="7" stroke="var(--color-burnt-orange)" strokeWidth="1.5"/>
              <path d="M8 5v3.5" stroke="var(--color-burnt-orange)" strokeWidth="1.5" strokeLinecap="round"/>
              <circle cx="8" cy="11.5" r="0.75" fill="var(--color-burnt-orange)"/>
            </svg>
          </div>
          <div>
            <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--color-carbon)', marginBottom: 4 }}>
              Single Source of Truth Architecture
            </div>
            <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', margin: 0, lineHeight: 1.7 }}>
              The Admin Console reads exclusively from the deployed backend database.
              Connectivity state reflects real authenticated sensor contact thresholds (5 min),
              while telemetry freshness reflects actual sensor measurement delivery via the
              NAADYANTRA ESP32 firmware pipeline.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

export default Overview;
