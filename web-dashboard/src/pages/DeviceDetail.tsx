import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { apiClient } from '../api/client';
import type { Device, DeviceStatus, LatestTelemetryResponse, Event } from '../types';

function DeviceDetail() {
  const { deviceId } = useParams<{ deviceId: string }>();

  const [device, setDevice] = useState<Device | null>(null);
  const [status, setStatus] = useState<DeviceStatus | null>(null);
  const [telemetry, setTelemetry] = useState<LatestTelemetryResponse | null>(null);
  const [events, setEvents] = useState<Event[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  // Key rotation modal state
  const [isRotatingKey, setIsRotatingKey] = useState(false);
  const [issuedKey, setIssuedKey] = useState<string | null>(null);
  const [rotationMessage, setRotationMessage] = useState('');
  const [isCopied, setIsCopied] = useState(false);

  useEffect(() => {
    if (deviceId) {
      loadDeviceData();
    }
  }, [deviceId]);

  // Polling for live telemetry every 5 seconds
  useEffect(() => {
    if (!deviceId) return;
    const interval = setInterval(() => {
      fetchLatestTelemetry(deviceId);
    }, 5000);
    return () => clearInterval(interval);
  }, [deviceId]);

  const fetchLatestTelemetry = async (id: string) => {
    try {
      const tel = await apiClient.getLatestTelemetry(id);
      setTelemetry(tel);
    } catch {
      // Keep existing state on transient poll failure
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
    if (!confirm('Are you sure you want to rotate the credential for this device? The old key will immediately be revoked.')) {
      return;
    }
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
    if (!confirm('Are you sure you want to deactivate this device? It will no longer be permitted to ingest telemetry.')) {
      return;
    }
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

  const formatTimestamp = (timestamp?: string | null) => {
    if (!timestamp) return 'Never';
    return new Date(timestamp).toLocaleString();
  };

  if (isLoading) {
    return <div className="text-warmGraphite py-8">Loading device details...</div>;
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded mb-6">
        {error}
      </div>
    );
  }

  if (!device || !status) {
    return <div className="text-warmGraphite">Device not found</div>;
  }

  return (
    <div>
      <div className="mb-6 flex justify-between items-center">
        <Link to="/devices" className="text-burntOrange hover:text-darkBurntOrange font-medium text-sm">
          ← Back to Device Inventory
        </Link>
        <div className="flex gap-3">
          <button
            onClick={loadDeviceData}
            className="px-3 py-1.5 text-xs bg-white border border-warmStone rounded hover:bg-softSand text-obsidian font-medium transition-colors"
          >
            Refresh
          </button>
          <button
            onClick={handleRotateKey}
            disabled={isRotatingKey}
            className="px-3 py-1.5 text-xs bg-burntOrange text-white font-medium rounded hover:bg-darkBurntOrange transition-colors"
          >
            Rotate Credential
          </button>
          {device.is_active && (
            <button
              onClick={handleDeactivate}
              className="px-3 py-1.5 text-xs border border-red-300 text-red-700 rounded hover:bg-red-50 font-medium transition-colors"
            >
              Deactivate
            </button>
          )}
        </div>
      </div>

      {/* Device Header */}
      <div className="flex items-center gap-4 mb-6">
        <h2 className="text-2xl font-bold text-obsidian">{device.device_id}</h2>
        <span
          className={`px-3 py-1 text-xs font-semibold rounded-full ${
            status.is_online ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
          }`}
        >
          {status.is_online ? '● Online (Contacted)' : '○ Offline'}
        </span>
        {!device.is_active && (
          <span className="px-3 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800">
            Deactivated
          </span>
        )}
      </div>

      {/* Live Telemetry Freshness Card */}
      <div className="bg-white rounded-lg shadow p-6 mb-6 border border-warmStone">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-obsidian">Live Ingested Telemetry</h3>
          {telemetry && (
            <span
              className={`text-xs font-medium px-2.5 py-1 rounded-full ${
                !telemetry.has_data
                  ? 'bg-gray-100 text-gray-700'
                  : telemetry.is_stale
                  ? 'bg-yellow-100 text-yellow-800'
                  : 'bg-green-100 text-green-800'
              }`}
            >
              {!telemetry.has_data
                ? 'No Telemetry Recorded'
                : telemetry.is_stale
                ? `Stale (${telemetry.staleness_seconds}s ago)`
                : `Live Fresh (${telemetry.staleness_seconds}s ago)`}
            </span>
          )}
        </div>

        {telemetry && telemetry.event ? (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 bg-softSand/20 p-4 rounded-lg border border-warmStone">
            <div>
              <p className="text-xs text-warmGraphite uppercase font-medium">Acoustic RMS</p>
              <p className="text-xl font-bold text-obsidian">
                {telemetry.event.rms != null ? telemetry.event.rms.toFixed(1) : '—'}
                <span className="text-xs font-normal text-warmGraphite ml-1">counts</span>
              </p>
            </div>
            <div>
              <p className="text-xs text-warmGraphite uppercase font-medium">Gas Delta (ADC)</p>
              <p className="text-xl font-bold text-obsidian">
                {telemetry.event.gas_delta != null ? telemetry.event.gas_delta : '—'}
                <span className="text-xs font-normal text-warmGraphite ml-1">Δ counts</span>
              </p>
            </div>
            <div>
              <p className="text-xs text-warmGraphite uppercase font-medium">Moisture / Wet</p>
              <p className="text-xl font-bold text-obsidian">
                {telemetry.event.wet === true ? (
                  <span className="text-alertDanger">WET (Detected)</span>
                ) : telemetry.event.wet === false ? (
                  <span className="text-alertOk">DRY (Normal)</span>
                ) : (
                  'Not fitted'
                )}
              </p>
            </div>
            <div>
              <p className="text-xs text-warmGraphite uppercase font-medium">Alert Level</p>
              <p className="text-xl font-bold">
                <span
                  className={
                    telemetry.event.alert === 'DANGER'
                      ? 'text-alertDanger'
                      : telemetry.event.alert === 'CAUTION'
                      ? 'text-alertCaution'
                      : 'text-alertOk'
                  }
                >
                  {telemetry.event.alert || 'NORMAL'}
                </span>
              </p>
            </div>
            <div>
              <p className="text-xs text-warmGraphite uppercase font-medium">Temperature</p>
              <p className="text-sm font-semibold text-obsidian">
                {telemetry.event.temperature != null ? `${telemetry.event.temperature}°C` : 'Disabled in FW'}
              </p>
            </div>
            <div>
              <p className="text-xs text-warmGraphite uppercase font-medium">Gas Ratio (Rs/R0)</p>
              <p className="text-sm font-semibold text-obsidian">
                {telemetry.event.gas_ratio != null ? telemetry.event.gas_ratio.toFixed(2) : '—'}
              </p>
            </div>
            <div>
              <p className="text-xs text-warmGraphite uppercase font-medium">Detection Cause</p>
              <p className="text-sm font-semibold text-obsidian">
                {telemetry.event.cause || 'ambient_baseline'}
              </p>
            </div>
            <div>
              <p className="text-xs text-warmGraphite uppercase font-medium">Server Ingested At</p>
              <p className="text-xs text-warmGraphite">
                {formatTimestamp(telemetry.event.server_timestamp)}
              </p>
            </div>
          </div>
        ) : (
          <div className="p-4 bg-gray-50 border border-warmStone rounded text-sm text-warmGraphite text-center">
            Awaiting first telemetry payload from this device...
          </div>
        )}
      </div>

      {/* Device Metadata Card */}
      <div className="bg-white rounded-lg shadow p-6 mb-6 border border-warmStone">
        <h3 className="text-lg font-semibold text-obsidian mb-4">Device Metadata</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
          <div>
            <p className="text-warmGraphite">Device Name</p>
            <p className="font-semibold text-obsidian">{device.name || device.device_id}</p>
          </div>
          <div>
            <p className="text-warmGraphite">Firmware Version</p>
            <p className="font-semibold text-obsidian">{device.firmware_version || 'Not reported'}</p>
          </div>
          <div>
            <p className="text-warmGraphite">Last Contact (Heartbeat / Log)</p>
            <p className="font-semibold text-obsidian">{formatTimestamp(status.last_seen_at)}</p>
          </div>
          <div>
            <p className="text-warmGraphite">Last Telemetry Timestamp</p>
            <p className="font-semibold text-obsidian">{formatTimestamp(status.last_telemetry_at)}</p>
          </div>
          <div>
            <p className="text-warmGraphite">Registered At</p>
            <p className="font-semibold text-obsidian">{formatTimestamp(device.created_at)}</p>
          </div>
          <div>
            <p className="text-warmGraphite">24h Event Count</p>
            <p className="font-semibold text-obsidian">{status.recent_activity_count} events</p>
          </div>
        </div>
        {status.last_error && (
          <div className="mt-4 p-3 bg-red-50 border border-red-200 text-red-700 text-xs rounded">
            <span className="font-bold">Last Reported Ingestion Error:</span> {status.last_error}
          </div>
        )}
      </div>

      {/* Historical Telemetry & Events */}
      <div className="bg-white rounded-lg shadow p-6 border border-warmStone">
        <h3 className="text-lg font-semibold text-obsidian mb-4">Recent Event History</h3>
        {events.length === 0 ? (
          <p className="text-warmGraphite text-sm">No historical events recorded for this device.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-warmStone text-sm">
              <thead className="bg-warmStone">
                <tr>
                  <th className="px-4 py-2 text-left font-semibold text-warmGraphite uppercase text-xs">Time (UTC)</th>
                  <th className="px-4 py-2 text-left font-semibold text-warmGraphite uppercase text-xs">Event</th>
                  <th className="px-4 py-2 text-left font-semibold text-warmGraphite uppercase text-xs">Alert</th>
                  <th className="px-4 py-2 text-left font-semibold text-warmGraphite uppercase text-xs">Cause</th>
                  <th className="px-4 py-2 text-left font-semibold text-warmGraphite uppercase text-xs">RMS</th>
                  <th className="px-4 py-2 text-left font-semibold text-warmGraphite uppercase text-xs">Gas Δ</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-warmStone">
                {events.map((ev) => (
                  <tr key={ev.id} className="hover:bg-softSand/30">
                    <td className="px-4 py-2 text-warmGraphite text-xs">{formatTimestamp(ev.server_timestamp)}</td>
                    <td className="px-4 py-2 text-obsidian font-medium">{ev.event_name || 'telemetry'}</td>
                    <td className="px-4 py-2">
                      <span
                        className={`px-2 py-0.5 text-xs font-semibold rounded ${
                          ev.alert === 'DANGER'
                            ? 'bg-red-100 text-red-800'
                            : ev.alert === 'CAUTION'
                            ? 'bg-yellow-100 text-yellow-800'
                            : 'bg-green-100 text-green-800'
                        }`}
                      >
                        {ev.alert || 'OK'}
                      </span>
                    </td>
                    <td className="px-4 py-2 text-warmGraphite text-xs">{ev.cause || '—'}</td>
                    <td className="px-4 py-2 text-obsidian font-mono text-xs">{ev.rms != null ? ev.rms.toFixed(1) : '—'}</td>
                    <td className="px-4 py-2 text-obsidian font-mono text-xs">{ev.gas_delta ?? '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* One-Time Key Modal */}
      {issuedKey && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6 border border-warmStone">
            <h3 className="text-lg font-bold text-obsidian mb-2">New Device Credential Issued</h3>
            <p className="text-xs text-warmGraphite mb-4">{rotationMessage}</p>
            <div className="bg-softSand/40 p-3 rounded font-mono text-sm break-all select-all border border-warmStone mb-4">
              {issuedKey}
            </div>
            <div className="flex justify-between items-center">
              <button
                onClick={() => copyToClipboard(issuedKey)}
                className="px-4 py-2 bg-burntOrange text-white text-xs font-medium rounded hover:bg-darkBurntOrange transition-colors"
              >
                {isCopied ? 'Copied!' : 'Copy to Clipboard'}
              </button>
              <button
                onClick={() => setIssuedKey(null)}
                className="px-4 py-2 bg-gray-200 text-obsidian text-xs font-medium rounded hover:bg-gray-300"
              >
                Dismiss
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default DeviceDetail;
