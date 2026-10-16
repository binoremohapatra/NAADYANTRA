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

  // Register Device Modal state
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

  const filteredDevices =
    devices?.items.filter((device) => {
      if (filter === 'all') return true;
      const isOnline = device.is_online ?? false;
      if (filter === 'online') return isOnline;
      if (filter === 'offline') return !isOnline;
      return true;
    }) || [];

  const formatLastSeen = (lastSeen: string | null) => {
    if (!lastSeen) return 'Never';
    const date = new Date(lastSeen);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    return date.toLocaleDateString();
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-obsidian">Device Inventory</h2>
          <p className="text-sm text-warmGraphite">
            Registered sensing wearables and diagnostic hardware units
          </p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={() => setShowRegisterModal(true)}
            className="px-4 py-2 bg-burntOrange text-white text-sm font-semibold rounded hover:bg-darkBurntOrange transition-colors"
          >
            + Register Device
          </button>
          <button
            onClick={loadDevices}
            className="px-3 py-2 text-sm bg-white border border-warmStone rounded hover:bg-softSand text-obsidian font-medium transition-colors"
          >
            Refresh
          </button>
        </div>
      </div>

      {/* Filters Bar */}
      <div className="bg-white rounded-lg shadow p-4 mb-6 border border-warmStone">
        <div className="flex flex-col md:flex-row gap-4">
          <input
            type="text"
            placeholder="Search by device ID or name..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="flex-1 px-3 py-2 border border-warmStone rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
          />
          <div className="flex gap-2">
            <button
              onClick={() => setFilter('all')}
              className={`px-4 py-2 rounded-md text-xs font-semibold transition-colors ${
                filter === 'all'
                  ? 'bg-burntOrange text-white'
                  : 'bg-warmStone text-warmGraphite hover:bg-softSand'
              }`}
            >
              All ({devices?.total ?? 0})
            </button>
            <button
              onClick={() => setFilter('online')}
              className={`px-4 py-2 rounded-md text-xs font-semibold transition-colors ${
                filter === 'online'
                  ? 'bg-burntOrange text-white'
                  : 'bg-warmStone text-warmGraphite hover:bg-softSand'
              }`}
            >
              Online
            </button>
            <button
              onClick={() => setFilter('offline')}
              className={`px-4 py-2 rounded-md text-xs font-semibold transition-colors ${
                filter === 'offline'
                  ? 'bg-burntOrange text-white'
                  : 'bg-warmStone text-warmGraphite hover:bg-softSand'
              }`}
            >
              Offline
            </button>
          </div>
        </div>
      </div>

      {isLoading ? (
        <div className="text-warmGraphite py-8 text-center">Loading device inventory...</div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded mb-6">
          {error}
        </div>
      ) : filteredDevices.length === 0 ? (
        <div className="bg-white rounded-lg shadow p-8 border border-warmStone text-center text-warmGraphite">
          No matching devices found.
        </div>
      ) : (
        <div className="bg-white rounded-lg shadow border border-warmStone overflow-hidden">
          <table className="min-w-full divide-y divide-warmStone">
            <thead className="bg-warmStone">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Device ID
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Name
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Last Contact
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Firmware
                </th>
                <th className="px-6 py-3 text-right text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-warmStone">
              {filteredDevices.map((device) => (
                <tr key={device.id} className="hover:bg-softSand/30 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-bold text-obsidian">
                    <Link
                      to={`/devices/${device.device_id}`}
                      className="hover:text-burntOrange hover:underline"
                    >
                      {device.device_id}
                    </Link>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite">
                    {device.name || 'Unnamed Device'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    <span
                      className={`px-2.5 py-1 text-xs font-semibold rounded-full ${
                        device.is_online
                          ? 'bg-green-100 text-green-800'
                          : 'bg-gray-100 text-gray-800'
                      }`}
                    >
                      {device.is_online ? '● Online' : '○ Offline'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite">
                    {formatLastSeen(device.last_seen_at)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite font-mono text-xs">
                    {device.firmware_version || 'Not reported'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm">
                    <Link
                      to={`/devices/${device.device_id}`}
                      className="text-burntOrange hover:text-darkBurntOrange font-semibold text-xs"
                    >
                      Inspect Details →
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Pagination */}
          <div className="px-6 py-4 bg-white border-t border-warmStone flex items-center justify-between">
            <span className="text-sm text-warmGraphite">
              Total {devices?.total ?? 0} registered devices
            </span>
            <div className="flex gap-2">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page <= 1}
                className="px-3 py-1 text-sm border border-warmStone rounded disabled:opacity-40"
              >
                Previous
              </button>
              <span className="px-3 py-1 text-sm text-warmGraphite">
                Page {page} of {Math.max(1, Math.ceil((devices?.total ?? 0) / 50))}
              </span>
              <button
                onClick={() => setPage((p) => p + 1)}
                disabled={page * 50 >= (devices?.total ?? 0)}
                className="px-3 py-1 text-sm border border-warmStone rounded disabled:opacity-40"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Register Device Modal */}
      {showRegisterModal && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6 border border-warmStone">
            <h3 className="text-lg font-bold text-obsidian mb-2">Register New Sensing Device</h3>
            <p className="text-xs text-warmGraphite mb-4">
              Authorize a new ESP32 wearable unit. The device key must match the X-Device-Key header in firmware.
            </p>

            {registerError && (
              <div className="mb-4 p-2 bg-red-50 text-red-700 text-xs rounded border border-red-200">
                {registerError}
              </div>
            )}

            <form onSubmit={handleRegisterDevice} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-warmGraphite mb-1">
                  Device ID *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. SIH-DEV-02"
                  value={newDeviceId}
                  onChange={(e) => setNewDeviceId(e.target.value)}
                  className="w-full px-3 py-2 border border-warmStone rounded text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-warmGraphite mb-1">
                  Device Name / Label
                </label>
                <input
                  type="text"
                  placeholder="e.g. Workshop Station 2 Wearable"
                  value={newDeviceName}
                  onChange={(e) => setNewDeviceName(e.target.value)}
                  className="w-full px-3 py-2 border border-warmStone rounded text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-warmGraphite mb-1">
                  Device Authentication Key *
                </label>
                <input
                  type="password"
                  required
                  placeholder="Secure shared secret"
                  value={newDeviceKey}
                  onChange={(e) => setNewDeviceKey(e.target.value)}
                  className="w-full px-3 py-2 border border-warmStone rounded text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange font-mono"
                />
              </div>

              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowRegisterModal(false)}
                  className="px-4 py-2 border border-warmStone text-warmGraphite text-xs font-medium rounded hover:bg-softSand"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isRegistering}
                  className="px-4 py-2 bg-burntOrange text-white text-xs font-semibold rounded hover:bg-darkBurntOrange disabled:opacity-50"
                >
                  {isRegistering ? 'Registering...' : 'Save & Register'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

export default Devices;
