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
    const interval = setInterval(loadOverview, 10000);
    return () => clearInterval(interval);
  }, []);

  const loadOverview = async () => {
    try {
      setError('');

      // Check API readiness and system info
      try {
        const ready = await apiClient.readyCheck();
        setApiStatus('healthy');
        setDbStatus(ready.database || 'connected');
      } catch {
        setApiStatus('disconnected');
        setDbStatus('error');
      }

      // Load overview data
      const data = await apiClient.getDashboardOverview();
      setOverview(data);
      if (data.server_utc) {
        setServerUtc(new Date(data.server_utc).toLocaleTimeString());
      }

      // Load recorded alerts count
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
    return <div className="text-warmGraphite py-8">Loading operational overview...</div>;
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded mb-6">
        {error}
      </div>
    );
  }

  if (!overview) {
    return <div className="text-warmGraphite py-8">No data available from backend.</div>;
  }

  return (
    <div>
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-6">
        <div>
          <h2 className="text-2xl font-bold text-obsidian">Operational Overview</h2>
          <p className="text-sm text-warmGraphite">
            Canonical telemetry, device connectivity & training session aggregation
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          {/* API & DB Status Pills */}
          <div className="flex items-center gap-2 bg-white px-3 py-1.5 rounded-full border border-warmStone text-xs">
            <span
              className={`w-2 h-2 rounded-full ${
                apiStatus === 'healthy' ? 'bg-alertOk' : 'bg-alertDanger'
              }`}
            />
            <span className="text-warmGraphite">
              Backend: <strong className="text-obsidian">{apiStatus === 'healthy' ? 'Healthy' : 'Offline'}</strong>
            </span>
            <span className="text-warmStone">|</span>
            <span className="text-warmGraphite">
              DB: <strong className="text-obsidian">{dbStatus}</strong>
            </span>
          </div>

          {serverUtc && (
            <span className="text-xs text-warmGraphite font-mono bg-white px-2.5 py-1.5 rounded border border-warmStone">
              Server UTC: {serverUtc}
            </span>
          )}

          {lastRefresh && (
            <span className="text-xs text-warmGraphite">
              Refreshed: {lastRefresh.toLocaleTimeString()}
            </span>
          )}

          <button
            onClick={loadOverview}
            className="px-3 py-1.5 text-xs bg-white border border-warmStone rounded hover:bg-softSand text-obsidian font-medium transition-colors"
          >
            Refresh Now
          </button>
        </div>
      </div>

      {/* Primary Metrics Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 mb-8">
        {/* Total Registered Devices */}
        <div className="bg-white rounded-lg shadow p-5 border border-warmStone">
          <h3 className="text-xs font-semibold uppercase text-warmGraphite tracking-wider mb-2">
            Registered Devices
          </h3>
          <p className="text-3xl font-bold text-obsidian">{overview.total_devices}</p>
          <div className="mt-2 text-xs text-warmGraphite flex justify-between">
            <span>Online: <strong className="text-alertOk">{overview.online_devices_count ?? overview.active_devices_count}</strong></span>
            <span>Offline: <strong>{overview.offline_devices_count ?? (overview.total_devices - overview.active_devices_count)}</strong></span>
          </div>
        </div>

        {/* Telemetry Health */}
        <div className="bg-white rounded-lg shadow p-5 border border-warmStone">
          <h3 className="text-xs font-semibold uppercase text-warmGraphite tracking-wider mb-2">
            Telemetry Freshness
          </h3>
          <p className="text-3xl font-bold text-alertOk">
            {overview.online_devices_count ?? overview.active_devices_count}
          </p>
          <div className="mt-2 text-xs text-warmGraphite flex justify-between">
            <span>Stale: <strong className="text-alertCaution">{overview.stale_devices_count ?? 0}</strong></span>
            <span>No data: <strong>{overview.never_reported_count ?? 0}</strong></span>
          </div>
        </div>

        {/* Total Sessions */}
        <div className="bg-white rounded-lg shadow p-5 border border-warmStone">
          <h3 className="text-xs font-semibold uppercase text-warmGraphite tracking-wider mb-2">
            Training Sessions
          </h3>
          <p className="text-3xl font-bold text-obsidian">{overview.total_sessions}</p>
          <div className="mt-2 text-xs text-warmGraphite flex justify-between">
            <span>Last 24h: <strong className="text-burntOrange">{overview.recent_sessions_count}</strong></span>
            <span>Trainees: <strong>{overview.total_trainees}</strong></span>
          </div>
        </div>

        {/* Recorded Events & Alerts */}
        <div className="bg-white rounded-lg shadow p-5 border border-warmStone">
          <h3 className="text-xs font-semibold uppercase text-warmGraphite tracking-wider mb-2">
            Recorded Hazards & Alerts
          </h3>
          <p className="text-3xl font-bold text-alertDanger">{activeAlertsCount}</p>
          <div className="mt-2 text-xs text-warmGraphite flex justify-between">
            <span>Total Events: <strong>{overview.total_events}</strong></span>
            <span>Failures: <strong>{overview.recent_ingestion_failures_count ?? 0}</strong></span>
          </div>
        </div>
      </div>

      {/* Information Banner */}
      <div className="bg-white rounded-lg p-5 border border-warmStone text-sm text-warmGraphite">
        <h4 className="font-semibold text-obsidian mb-1">Single Source of Truth Architecture</h4>
        <p className="text-xs leading-relaxed">
          The Admin Console reads exclusively from the deployed backend database. Connectivity state reflects real authenticated sensor contact thresholds (5 minutes), while telemetry freshness reflects actual sensor measurement delivery.
        </p>
      </div>
    </div>
  );
}

export default Overview;
