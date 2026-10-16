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
    const date = new Date(timestamp);
    return date.toLocaleString();
  };

  if (isLoading) {
    return <div className="text-warmGraphite">Loading alerts...</div>;
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded">
        {error}
      </div>
    );
  }

  if (!alerts || alerts.items.length === 0) {
    return (
      <div className="bg-white rounded-lg shadow p-8 border border-warmStone text-center">
        <p className="text-warmGraphite">No alerts recorded yet.</p>
      </div>
    );
  }

  return (
    <div>
      <h2 className="text-2xl font-bold text-obsidian mb-6">Alerts</h2>

      {/* Filters */}
      <div className="bg-white rounded-lg shadow p-4 mb-6 border border-warmStone">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Severity Filter */}
          <div>
            <label className="block text-sm font-medium text-warmGraphite mb-2">Severity</label>
            <select
              value={filterType}
              onChange={(e) => setFilterType(e.target.value)}
              className="w-full px-3 py-2 border border-warmStone rounded-md focus:outline-none focus:ring-2 focus:ring-burntOrange"
            >
              <option value="">All</option>
              <option value="DANGER">Danger</option>
              <option value="CAUTION">Caution</option>
            </select>
          </div>
          {/* Device Filter */}
          <div>
            <label className="block text-sm font-medium text-warmGraphite mb-2">Device ID</label>
            <input
              type="text"
              placeholder="Filter by device ID..."
              value={filterDevice}
              onChange={(e) => setFilterDevice(e.target.value)}
              className="w-full px-3 py-2 border border-warmStone rounded-md focus:outline-none focus:ring-2 focus:ring-burntOrange"
            />
          </div>
        </div>
      </div>

      {/* Alerts Table */}
      <div className="bg-white rounded-lg shadow border border-warmStone overflow-hidden">
        <table className="min-w-full divide-y divide-warmStone">
          <thead className="bg-warmStone">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-warmGraphite uppercase tracking-wider">
                Timestamp
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-warmGraphite uppercase tracking-wider">
                Device ID
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-warmGraphite uppercase tracking-wider">
                Alert Level
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-warmGraphite uppercase tracking-wider">
                Cause
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-warmGraphite uppercase tracking-wider">
                Event Name
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-warmStone">
            {alerts.items.map((alert) => (
              <tr key={alert.id} className="hover:bg-industrialIvory">
                <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite">
                  {formatTimestamp(alert.timestamp)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-obsidian">
                  {alert.device_id}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span
                    className={`px-2 py-1 text-xs font-medium rounded ${
                      alert.alert === 'DANGER'
                        ? 'bg-red-100 text-red-800'
                        : alert.alert === 'CAUTION'
                        ? 'bg-yellow-100 text-yellow-800'
                        : 'bg-green-100 text-green-800'
                    }`}
                  >
                    {alert.alert}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite">
                  {alert.cause || 'N/A'}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite">
                  {alert.details.event_name || 'N/A'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {alerts.total > alerts.page_size && (
        <div className="mt-4 flex justify-between items-center">
          <p className="text-sm text-warmGraphite">
            Showing {((page - 1) * alerts.page_size) + 1} to{' '}
            {Math.min(page * alerts.page_size, alerts.total)} of {alerts.total} alerts
          </p>
          <div className="flex gap-2">
            <button
              onClick={() => setPage(Math.max(1, page - 1))}
              disabled={page === 1}
              className="px-4 py-2 bg-white border border-warmStone rounded-md disabled:opacity-50"
            >
              Previous
            </button>
            <button
              onClick={() => setPage(page + 1)}
              disabled={page * alerts.page_size >= alerts.total}
              className="px-4 py-2 bg-white border border-warmStone rounded-md disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default Alerts;
