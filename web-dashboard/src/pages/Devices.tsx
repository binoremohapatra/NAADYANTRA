import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { apiClient } from '../api/client';
import { useDemo } from '../context/DemoContext';
import { computeDeviceFreshness } from '../utils/telemetry';
import type { Device, PaginatedResponse } from '../types';

export default function Devices() {
  const { isDemoMode, demoData } = useDemo();

  const [devices, setDevices] = useState<PaginatedResponse<Device> | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');
  const [page, setPage] = useState<number>(1);
  const [search, setSearch] = useState<string>('');
  const [filter, setFilter] = useState<'all' | 'online' | 'stale' | 'offline'>('all');

  // Register Device Modal
  const [showRegisterModal, setShowRegisterModal] = useState<boolean>(false);
  const [newDeviceId, setNewDeviceId] = useState<string>('');
  const [newDeviceName, setNewDeviceName] = useState<string>('');
  const [newDeviceKey, setNewDeviceKey] = useState<string>('');
  const [isRegistering, setIsRegistering] = useState<boolean>(false);
  const [registerError, setRegisterError] = useState<string>('');

  const loadDevices = useCallback(async () => {
    try {
      setIsLoading(true);
      setError('');

      if (isDemoMode) {
        let items = [...demoData.devices];
        if (search.trim()) {
          const q = search.trim().toLowerCase();
          items = items.filter(
            (d) => d.device_id.toLowerCase().includes(q) || (d.name && d.name.toLowerCase().includes(q))
          );
        }
        setDevices({
          total: items.length,
          page,
          page_size: 50,
          items,
        });
        setIsLoading(false);
        return;
      }

      const params: any = { page, page_size: 50 };
      if (search) params.search = search;
      const data = await apiClient.getDevices(params);
      setDevices(data);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load devices');
    } finally {
      setIsLoading(false);
    }
  }, [isDemoMode, demoData.devices, page, search]);

  useEffect(() => {
    loadDevices();
  }, [loadDevices]);

  const handleRegisterDevice = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newDeviceId || !newDeviceKey) {
      setRegisterError('Device ID and Device Key are required.');
      return;
    }
    try {
      setIsRegistering(true);
      setRegisterError('');

      if (!isDemoMode) {
        await apiClient.registerDevice({
          device_id: newDeviceId.trim(),
          name: newDeviceName.trim() || undefined,
          device_key: newDeviceKey.trim(),
        });
      }

      setShowRegisterModal(false);
      setNewDeviceId('');
      setNewDeviceName('');
      setNewDeviceKey('');
      await loadDevices();
    } catch (err: any) {
      setRegisterError(err.response?.data?.detail || 'Registration failed');
    } finally {
      setIsRegistering(false);
    }
  };

  const filteredDevices =
    devices?.items.filter((device) => {
      const freshness = computeDeviceFreshness(device.last_telemetry_at || device.last_seen_at, 60, 300);
      if (filter === 'all') return true;
      if (filter === 'online') return freshness.state === 'online';
      if (filter === 'stale') return freshness.state === 'stale';
      if (filter === 'offline') return freshness.state === 'offline';
      return true;
    }) || [];

  const formatLastSeen = (lastSeen: string | null) => {
    if (!lastSeen) return 'Never';
    const freshness = computeDeviceFreshness(lastSeen, 60, 300);
    return freshness.label;
  };

  const totalPages = Math.max(1, Math.ceil((devices?.total ?? 0) / 50));

  return (
    <div>
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">Device Inventory</h1>
          <p className="hg-page-subtitle">Registered ESP32 sensing rigs, firmware versions &amp; hardware modalities</p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button className="hg-btn hg-btn-primary" onClick={() => setShowRegisterModal(true)}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M6.5 1v11M1 6.5h11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
            Register Device
          </button>
          <button className="hg-btn hg-btn-secondary" onClick={loadDevices}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
              <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            Refresh
          </button>
        </div>
      </div>

      {/* Same-Wi-Fi Fleet Discovery Architecture Callout */}
      <div
        className="hg-card"
        style={{
          marginBottom: 20,
          padding: '14px 20px',
          background: 'var(--color-pure-white)',
          borderLeft: '4px solid var(--color-burnt-orange)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 16 }}>📡</span>
          <h3 style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', margin: 0 }}>
            Fleet Architecture &amp; Same-Wi-Fi Multi-Device Monitoring
          </h3>
        </div>
        <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', marginTop: 6, lineHeight: 1.5 }}>
          <strong>Browser Sandbox vs Central Fleet Registry:</strong> Because this web console runs inside a sandboxed browser runtime,
          it cannot execute low-level ARP sweeps, raw socket broadcasts, or mDNS probes across a local Wi-Fi router (e.g. 192.168.x.x).
          Instead, all NAADYANTRA ESP32-S3 rigs operating on the workshop or facility Wi-Fi register outbound to the central NAADYANTRA backend
          (<span className="hg-code">POST /api/log</span>) using a persistent <span className="hg-code">device_id</span>.
          The backend maintains heartbeat timestamps (<span className="hg-code">last_seen_at</span>), enabling this dashboard to monitor all
          rigs on the facility network without requiring local subnet router bridges.
        </p>
      </div>

      {/* Filters Bar */}
      <div className="hg-card" style={{ marginBottom: 20, padding: '16px 20px' }}>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          <div style={{ flex: 1, minWidth: 200 }}>
            <label className="hg-label">Search</label>
            <input
              type="text"
              className="hg-input"
              placeholder="Search by device ID or name…"
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
            />
          </div>
          <div>
            <label className="hg-label">Status Filter</label>
            <div className="hg-tabs">
              {(['all', 'online', 'stale', 'offline'] as const).map((f) => (
                <button
                  key={f}
                  className={`hg-tab${filter === f ? ' active' : ''}`}
                  onClick={() => {
                    setFilter(f);
                    setPage(1);
                  }}
                >
                  {f === 'all'
                    ? `All (${devices?.total ?? 0})`
                    : f.charAt(0).toUpperCase() + f.slice(1)}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {isLoading && (
        <div className="hg-loading-screen">
          <div className="hg-spinner" />
          <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>Loading device inventory…</span>
        </div>
      )}

      {error && !isLoading && (
        <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>
          {error}
        </div>
      )}

      {!isLoading && !error && filteredDevices.length === 0 && (
        <div className="hg-card">
          <div className="hg-empty">
            <div className="hg-empty-icon">📡</div>
            <p className="hg-empty-title">No devices found</p>
            <p className="hg-empty-desc">Register a new device or change your status filter.</p>
          </div>
        </div>
      )}

      {!isLoading && filteredDevices.length > 0 && (
        <div className="hg-card" style={{ padding: 0, overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table className="hg-table">
              <thead>
                <tr>
                  <th>Device ID</th>
                  <th>Name / Location</th>
                  <th>Firmware</th>
                  <th>Hardware Modalities</th>
                  <th>Status</th>
                  <th>Last Telemetry</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredDevices.map((device) => (
                  <tr key={device.id}>
                    <td>
                      <span className="hg-code">{device.device_id}</span>
                    </td>
                    <td>
                      <strong>{device.name || 'Rig Sensor'}</strong>
                      {device.device_metadata?.location && (
                        <span style={{ display: 'block', fontSize: 11, color: 'var(--color-warm-graphite)' }}>
                          {device.device_metadata.location}
                        </span>
                      )}
                    </td>
                    <td>
                      <span className="hg-badge hg-badge-neutral">{device.firmware_version || '1.1.0'}</span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                        <span className="hg-badge hg-badge-ok" style={{ fontSize: 9 }}>PIEZO</span>
                        <span className="hg-badge hg-badge-caution" style={{ fontSize: 9 }}>MQ-2 (REL)</span>
                        <span className="hg-badge hg-badge-ok" style={{ fontSize: 9 }}>MOIST</span>
                        <span className="hg-state-badge hg-state-disabled" style={{ fontSize: 9, padding: '2px 4px' }}>IR/UV OFF</span>
                      </div>
                    </td>
                    <td>
                      {(() => {
                        const freshness = computeDeviceFreshness(device.last_telemetry_at || device.last_seen_at, 60, 300);
                        if (freshness.state === 'online') {
                          return (
                            <span className="hg-badge hg-badge-ok">
                              <span className="hg-dot hg-dot-ok hg-dot-pulse" style={{ width: 6, height: 6 }} />
                              Online
                            </span>
                          );
                        }
                        if (freshness.state === 'stale') {
                          return (
                            <span className="hg-badge hg-badge-caution">
                              <span className="hg-dot hg-dot-caution" style={{ width: 6, height: 6 }} />
                              Stale
                            </span>
                          );
                        }
                        return <span className="hg-badge hg-badge-neutral">Offline</span>;
                      })()}
                    </td>
                    <td style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--color-warm-graphite)', whiteSpace: 'nowrap' }}>
                      {formatLastSeen(device.last_telemetry_at || device.last_seen_at)}
                    </td>
                    <td>
                      <Link
                        to={`/devices/${device.device_id}`}
                        className="hg-btn hg-btn-secondary"
                        style={{ padding: '4px 12px', fontSize: 11, textDecoration: 'none' }}
                      >
                        Inspect &amp; Manage →
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

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
                Showing {filteredDevices.length} of {devices?.total ?? 0} devices
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

      {/* Register Device Modal */}
      {showRegisterModal && (
        <div className="hg-modal-backdrop" onClick={() => setShowRegisterModal(false)}>
          <div className="hg-modal" style={{ maxWidth: 440 }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h3 style={{ fontSize: 16, margin: 0 }}>Register Hardware Rig</h3>
              <button className="hg-close-btn" onClick={() => setShowRegisterModal(false)}>×</button>
            </div>
            <form onSubmit={handleRegisterDevice}>
              <div style={{ marginBottom: 14 }}>
                <label className="hg-label">Device Identifier (ID)</label>
                <input
                  type="text"
                  className="hg-input"
                  placeholder="e.g. SIH-DEV-04"
                  value={newDeviceId}
                  onChange={(e) => setNewDeviceId(e.target.value)}
                  required
                />
              </div>
              <div style={{ marginBottom: 14 }}>
                <label className="hg-label">Friendly Name / Bench Location</label>
                <input
                  type="text"
                  className="hg-input"
                  placeholder="e.g. Lab Bench 4 (HVAC Testing)"
                  value={newDeviceName}
                  onChange={(e) => setNewDeviceName(e.target.value)}
                />
              </div>
              <div style={{ marginBottom: 20 }}>
                <label className="hg-label">Provisioning Device Key</label>
                <input
                  type="password"
                  className="hg-input"
                  placeholder="Secret key flashed to firmware credentials.h"
                  value={newDeviceKey}
                  onChange={(e) => setNewDeviceKey(e.target.value)}
                  required
                />
              </div>
              {registerError && (
                <div className="hg-alert hg-alert-error" style={{ marginBottom: 14 }}>
                  {registerError}
                </div>
              )}
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
                <button type="button" className="hg-btn hg-btn-secondary" onClick={() => setShowRegisterModal(false)}>
                  Cancel
                </button>
                <button type="submit" className="hg-btn hg-btn-primary" disabled={isRegistering}>
                  {isRegistering ? 'Registering…' : 'Register Rig'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
