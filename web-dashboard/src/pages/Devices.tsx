import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { apiClient } from '../api/client';
import type { Device, PaginatedResponse } from '../types';

function Devices() {
  const [devices, setDevices] = useState<PaginatedResponse<Device> | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'all' | 'online' | 'offline'>('all');

  // Register Device Modal
  const [showRegisterModal, setShowRegisterModal] = useState(false);
  const [newDeviceId, setNewDeviceId] = useState('');
  const [newDeviceName, setNewDeviceName] = useState('');
  const [newDeviceKey, setNewDeviceKey] = useState('');
  const [isRegistering, setIsRegistering] = useState(false);
  const [registerError, setRegisterError] = useState('');

  useEffect(() => {
    loadDevices();
  }, [page, search, filter]);

  const loadDevices = async () => {
    try {
      setIsLoading(true);
      setError('');
      const params: any = { page, page_size: 50 };
      if (search) params.search = search;
      const data = await apiClient.getDevices(params);
      setDevices(data);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load devices');
    } finally {
      setIsLoading(false);
    }
  };

  const handleRegisterDevice = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newDeviceId || !newDeviceKey) {
      setRegisterError('Device ID and Device Key are required.');
      return;
    }
    try {
      setIsRegistering(true);
      setRegisterError('');
      await apiClient.registerDevice({
        device_id: newDeviceId.trim(),
        name: newDeviceName.trim() || undefined,
        device_key: newDeviceKey.trim(),
      });
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

  const filteredDevices = devices?.items.filter((device) => {
    if (filter === 'all') return true;
    if (filter === 'online') return device.is_online ?? false;
    if (filter === 'offline') return !(device.is_online ?? false);
    return true;
  }) || [];

  const formatLastSeen = (lastSeen: string | null) => {
    if (!lastSeen) return 'Never';
    const diffMins = Math.floor((Date.now() - new Date(lastSeen).getTime()) / 60000);
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    return new Date(lastSeen).toLocaleDateString();
  };

  const totalPages = Math.max(1, Math.ceil((devices?.total ?? 0) / 50));

  return (
    <div>
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">Device Inventory</h1>
          <p className="hg-page-subtitle">Registered ESP32 sensing wearables and diagnostic hardware</p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button className="hg-btn hg-btn-primary" onClick={() => setShowRegisterModal(true)}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M6.5 1v11M1 6.5h11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
            Register Device
          </button>
          <button className="hg-btn hg-btn-secondary" onClick={loadDevices}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
              <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            Refresh
          </button>
        </div>
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
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            />
          </div>
          <div>
            <label className="hg-label">Status</label>
            <div className="hg-tabs">
              {(['all', 'online', 'offline'] as const).map((f) => (
                <button
                  key={f}
                  className={`hg-tab${filter === f ? ' active' : ''}`}
                  onClick={() => { setFilter(f); setPage(1); }}
                >
                  {f === 'all' ? `All (${devices?.total ?? 0})` : f.charAt(0).toUpperCase() + f.slice(1)}
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
        <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>{error}</div>
      )}

      {!isLoading && !error && filteredDevices.length === 0 && (
        <div className="hg-card">
          <div className="hg-empty">
            <div className="hg-empty-icon">📡</div>
            <p className="hg-empty-title">No matching devices</p>
            <p className="hg-empty-desc">
              {devices?.total === 0
                ? 'No devices registered yet. Click "Register Device" to add one.'
                : 'No devices match the current search and filter.'}
            </p>
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
                  <th>Name / Label</th>
                  <th>Status</th>
                  <th>Last Contact</th>
                  <th>Firmware</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredDevices.map((device) => (
                  <tr key={device.id}>
                    <td>
                      <Link
                        to={`/devices/${device.device_id}`}
                        style={{
                          fontFamily: 'var(--font-mono)',
                          fontWeight: 600,
                          color: 'var(--color-burnt-orange)',
                          textDecoration: 'none',
                          fontSize: 13,
                        }}
                      >
                        {device.device_id}
                      </Link>
                    </td>
                    <td style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>
                      {device.name || <span style={{ opacity: 0.5 }}>Unnamed</span>}
                    </td>
                    <td>
                      {device.is_online ? (
                        <span className="hg-badge hg-badge-ok">
                          <span className="hg-dot hg-dot-ok hg-dot-pulse" style={{ width: 6, height: 6 }} />
                          Online
                        </span>
                      ) : (
                        <span className="hg-badge hg-badge-neutral">
                          <span className="hg-dot hg-dot-neutral" style={{ width: 6, height: 6 }} />
                          Offline
                        </span>
                      )}
                    </td>
                    <td>
                      <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--color-warm-graphite)' }}>
                        {formatLastSeen(device.last_seen_at)}
                      </span>
                    </td>
                    <td>
                      {device.firmware_version ? (
                        <code className="hg-code">{device.firmware_version}</code>
                      ) : (
                        <span style={{ color: 'var(--color-soft-sand)', fontSize: 12 }}>—</span>
                      )}
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <Link
                        to={`/devices/${device.device_id}`}
                        className="hg-btn hg-btn-secondary"
                        style={{ padding: '5px 10px', fontSize: 12, textDecoration: 'none' }}
                      >
                        Inspect →
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="hg-pagination" style={{ padding: '12px 20px' }}>
            <span style={{ fontSize: 13, color: 'var(--color-warm-graphite)' }}>
              {devices?.total ?? 0} total device{(devices?.total ?? 0) !== 1 ? 's' : ''} · Page {page}/{totalPages}
            </span>
            <div style={{ display: 'flex', gap: 6 }}>
              <button
                className="hg-btn hg-btn-secondary"
                style={{ padding: '6px 12px' }}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page <= 1}
              >
                ← Prev
              </button>
              <button
                className="hg-btn hg-btn-secondary"
                style={{ padding: '6px 12px' }}
                onClick={() => setPage((p) => p + 1)}
                disabled={page >= totalPages}
              >
                Next →
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Register Device Modal */}
      {showRegisterModal && (
        <div className="hg-modal-backdrop" onClick={(e) => { if (e.target === e.currentTarget) setShowRegisterModal(false); }}>
          <div className="hg-modal">
            <div className="hg-modal-header">
              <span className="hg-modal-title">Register New Sensing Device</span>
              <button className="hg-close-btn" onClick={() => setShowRegisterModal(false)}>×</button>
            </div>
            <div className="hg-modal-body">
              <p style={{ fontSize: 13, color: 'var(--color-warm-graphite)', margin: '0 0 16px' }}>
                Authorize a new ESP32 wearable unit. The device key must match the
                <code className="hg-code" style={{ margin: '0 4px' }}>X-Device-Key</code>
                header in firmware.
              </p>

              {registerError && (
                <div className="hg-alert hg-alert-error" style={{ marginBottom: 16 }}>
                  {registerError}
                </div>
              )}

              <form id="register-device-form" onSubmit={handleRegisterDevice}>
                <div className="hg-form-group">
                  <label className="hg-label">Device ID *</label>
                  <input
                    type="text"
                    className="hg-input"
                    required
                    placeholder="e.g. SIH-DEV-02"
                    value={newDeviceId}
                    onChange={(e) => setNewDeviceId(e.target.value)}
                  />
                </div>

                <div className="hg-form-group">
                  <label className="hg-label">Name / Label</label>
                  <input
                    type="text"
                    className="hg-input"
                    placeholder="e.g. Workshop Station 2 Wearable"
                    value={newDeviceName}
                    onChange={(e) => setNewDeviceName(e.target.value)}
                  />
                </div>

                <div className="hg-form-group" style={{ marginBottom: 0 }}>
                  <label className="hg-label">Authentication Key *</label>
                  <input
                    type="password"
                    className="hg-input"
                    required
                    placeholder="Secure shared secret"
                    style={{ fontFamily: 'var(--font-mono)' }}
                    value={newDeviceKey}
                    onChange={(e) => setNewDeviceKey(e.target.value)}
                  />
                </div>
              </form>
            </div>
            <div className="hg-modal-footer">
              <button
                type="button"
                className="hg-btn hg-btn-secondary"
                onClick={() => setShowRegisterModal(false)}
              >
                Cancel
              </button>
              <button
                type="submit"
                form="register-device-form"
                className="hg-btn hg-btn-primary"
                disabled={isRegistering}
              >
                {isRegistering ? (
                  <>
                    <span className="hg-spinner" style={{ width: 14, height: 14, borderWidth: 2 }} />
                    Registering…
                  </>
                ) : (
                  'Save & Register'
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default Devices;
