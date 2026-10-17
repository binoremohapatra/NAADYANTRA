import { useState, useEffect } from 'react';
import { apiClient } from '../api/client';
import type { Session, PaginatedResponse } from '../types';

function Sessions() {
  const [sessions, setSessions] = useState<PaginatedResponse<Session> | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [selectedDeviceId, setSelectedDeviceId] = useState('');
  const [selectedTraineeId, setSelectedTraineeId] = useState('');

  useEffect(() => {
    loadSessions();
  }, [page, selectedDeviceId, selectedTraineeId]);

  const loadSessions = async () => {
    try {
      setIsLoading(true);
      setError('');
      const params: any = { page, page_size: 25 };
      if (selectedDeviceId) params.device_id = selectedDeviceId;
      if (selectedTraineeId) params.trainee_id = selectedTraineeId;
      const data = await apiClient.getSessions(params);
      setSessions(data);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load sessions');
    } finally {
      setIsLoading(false);
    }
  };

  const formatTimestamp = (timestamp: string | null) => {
    if (!timestamp) return 'In Progress';
    return new Date(timestamp).toLocaleString();
  };

  const calculateDuration = (start: string, end: string | null) => {
    if (!end) return 'Active';
    const s = new Date(start).getTime();
    const e = new Date(end).getTime();
    const sec = Math.max(0, Math.floor((e - s) / 1000));
    const mins = Math.floor(sec / 60);
    const remSec = sec % 60;
    return `${mins}m ${remSec}s`;
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-obsidian">Training Sessions</h2>
          <p className="text-sm text-warmGraphite">
            Recorded trainee diagnostic sessions with device linkage
          </p>
        </div>
        <button
          onClick={loadSessions}
          className="px-3 py-1.5 text-sm bg-white border border-warmStone rounded hover:bg-softSand text-obsidian transition-colors"
        >
          Refresh
        </button>
      </div>

      {/* Filter Bar */}
      <div className="bg-white rounded-lg shadow p-4 mb-6 border border-warmStone flex flex-col sm:flex-row gap-4">
        <input
          type="text"
          placeholder="Filter by Device ID (e.g. SIH-DEV-01)..."
          value={selectedDeviceId}
          onChange={(e) => {
            setSelectedDeviceId(e.target.value);
            setPage(1);
          }}
          className="flex-1 px-3 py-2 border border-warmStone rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
        />
        <input
          type="text"
          placeholder="Filter by Trainee ID (e.g. T001)..."
          value={selectedTraineeId}
          onChange={(e) => {
            setSelectedTraineeId(e.target.value);
            setPage(1);
          }}
          className="flex-1 px-3 py-2 border border-warmStone rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
        />
      </div>

      {isLoading ? (
        <div className="text-warmGraphite py-8 text-center">Loading training sessions...</div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded mb-6">
          {error}
        </div>
      ) : !sessions || sessions.items.length === 0 ? (
        <div className="bg-white rounded-lg shadow p-8 border border-warmStone text-center text-warmGraphite">
          No training sessions found.
        </div>
      ) : (
        <div className="bg-white rounded-lg shadow border border-warmStone overflow-hidden">
          <table className="min-w-full divide-y divide-warmStone">
            <thead className="bg-warmStone">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Session ID
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Device ID
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Trainee
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Started At
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Duration
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-right text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-warmStone">
              {sessions.items.map((session) => (
                <tr key={session.id} className="hover:bg-softSand/30 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-obsidian">
                    #{session.session_id}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite">
                    {session.device_id}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-burntOrange">
                    {session.trainee_id}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite">
                    {formatTimestamp(session.started_at)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite">
                    {calculateDuration(session.started_at, session.ended_at)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    <span
                      className={`px-2.5 py-1 text-xs font-semibold rounded-full ${
                        session.ended_at
                          ? 'bg-gray-100 text-gray-800'
                          : 'bg-green-100 text-green-800'
                      }`}
                    >
                      {session.ended_at ? 'Completed' : 'Active'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm">
                    <button
                      onClick={async () => {
                        try {
                          const res = await apiClient.exportSessionCsv(session.id);
                          const blob = new Blob([res.data], { type: 'text/csv' });
                          const url = window.URL.createObjectURL(blob);
                          const a = document.createElement('a');
                          a.href = url;
                          a.download = res.filename || `session_${session.id}_export.csv`;
                          a.click();
                          window.URL.revokeObjectURL(url);
                        } catch (err) {
                          alert('Failed to export session telemetry CSV');
                        }
                      }}
                      className="px-2.5 py-1 text-xs font-medium bg-offWhite border border-warmStone text-obsidian rounded hover:border-burntOrange hover:text-burntOrange transition-colors"
                    >
                      Export CSV
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Pagination */}
          <div className="px-6 py-4 bg-white border-t border-warmStone flex items-center justify-between">
            <span className="text-sm text-warmGraphite">
              Total {sessions.total} session records
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
                Page {page} of {Math.max(1, Math.ceil(sessions.total / 25))}
              </span>
              <button
                onClick={() => setPage((p) => p + 1)}
                disabled={page * 25 >= sessions.total}
                className="px-3 py-1 text-sm border border-warmStone rounded disabled:opacity-40"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default Sessions;
