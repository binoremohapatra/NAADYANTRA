import { useState, useEffect } from 'react';
import { apiClient } from '../api/client';
import type { Trainee, Session, Assessment, PaginatedResponse } from '../types';

export default function Trainees() {
  const [trainees, setTrainees] = useState<PaginatedResponse<Trainee> | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [cohortFilter, setCohortFilter] = useState('');
  const [page, setPage] = useState(1);

  // New trainee modal state
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [newTraineeId, setNewTraineeId] = useState('');
  const [newName, setNewName] = useState('');
  const [newCohort, setNewCohort] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  // Performance history modal
  const [selectedTrainee, setSelectedTrainee] = useState<Trainee | null>(null);
  const [traineeSessions, setTraineeSessions] = useState<Session[]>([]);
  const [traineeAssessments, setTraineeAssessments] = useState<Assessment[]>([]);
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);

  useEffect(() => {
    loadTrainees();
  }, [page, search, cohortFilter]);

  const loadTrainees = async () => {
    try {
      setIsLoading(true);
      setError('');
      const params: any = { page, page_size: 25 };
      if (search.trim()) params.search = search.trim();
      if (cohortFilter.trim()) params.cohort = cohortFilter.trim();
      const res = await apiClient.getTrainees(params);
      setTrainees(res);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load trainee directory');
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreateTrainee = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTraineeId.trim() || !newName.trim()) {
      setFormError('Trainee ID and full name are required');
      return;
    }
    try {
      setIsSubmitting(true);
      setFormError('');
      await apiClient.createTrainee({
        trainee_id: newTraineeId.trim().toUpperCase(),
        name: newName.trim(),
        cohort: newCohort.trim() || undefined,
      });
      setIsModalOpen(false);
      setNewTraineeId('');
      setNewName('');
      setNewCohort('');
      await loadTrainees();
    } catch (err: any) {
      setFormError(err.response?.data?.detail || 'Failed to create trainee record');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleViewPerformance = async (t: Trainee) => {
    setSelectedTrainee(t);
    setIsLoadingHistory(true);
    try {
      const [sessRes, assessRes] = await Promise.all([
        apiClient.getTraineeSessions(t.trainee_id, { page: 1, page_size: 10 }),
        apiClient.getTraineeAssessments(t.trainee_id, { page: 1, page_size: 10 }),
      ]);
      setTraineeSessions(sessRes.items);
      setTraineeAssessments(assessRes.items);
    } catch (err) {
      console.error('Failed to load performance details', err);
    } finally {
      setIsLoadingHistory(false);
    }
  };

  return (
    <div>
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6">
        <div>
          <h2 className="text-2xl font-bold text-obsidian tracking-tight">Trainee Directory</h2>
          <p className="text-sm text-warmGraphite">
            Vocational candidates enrolled in acoustic inspection and leak diagnostic training
          </p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={() => setIsModalOpen(true)}
            className="px-4 py-2 text-sm font-medium bg-burntOrange text-white rounded hover:bg-darkBurntOrange transition-colors shadow-sm"
          >
            + Register Trainee
          </button>
          <button
            onClick={loadTrainees}
            className="px-3 py-1.5 text-sm bg-white border border-warmStone rounded hover:bg-softSand text-obsidian transition-colors"
          >
            Refresh
          </button>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="bg-white rounded-lg shadow-sm p-4 mb-6 border border-warmStone flex flex-col sm:flex-row gap-4">
        <input
          type="text"
          placeholder="Search by ID or Candidate Name..."
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
          className="flex-1 px-3 py-2 border border-warmStone rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
        />
        <input
          type="text"
          placeholder="Filter by Cohort (e.g. Cohort-2026A)..."
          value={cohortFilter}
          onChange={(e) => {
            setCohortFilter(e.target.value);
            setPage(1);
          }}
          className="w-full sm:w-64 px-3 py-2 border border-warmStone rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
        />
      </div>

      {/* Content */}
      {isLoading ? (
        <div className="text-warmGraphite py-12 text-center">Loading trainee roster...</div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded mb-6">{error}</div>
      ) : !trainees || trainees.items.length === 0 ? (
        <div className="bg-white rounded-lg shadow-sm p-12 border border-warmStone text-center">
          <div className="w-12 h-12 mx-auto mb-3 rounded-full bg-softSand/50 flex items-center justify-center text-warmGraphite">
            👥
          </div>
          <h3 className="text-lg font-semibold text-obsidian mb-1">No Trainees Registered</h3>
          <p className="text-sm text-warmGraphite max-w-md mx-auto mb-6">
            No vocational candidates have been added to the system yet. Register trainees to link diagnostic sessions and skill assessments.
          </p>
          <button
            onClick={() => setIsModalOpen(true)}
            className="px-4 py-2 text-sm font-medium bg-burntOrange text-white rounded hover:bg-darkBurntOrange transition-colors"
          >
            Register First Candidate
          </button>
        </div>
      ) : (
        <div className="bg-white rounded-lg shadow-sm border border-warmStone overflow-hidden">
          <table className="min-w-full divide-y divide-warmStone">
            <thead className="bg-warmStone/60">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Trainee ID
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Full Name
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Cohort
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                  Enrolled On
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
              {trainees.items.map((t) => (
                <tr key={t.id} className="hover:bg-softSand/20 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-mono font-bold text-burntOrange">
                    {t.trainee_id}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-obsidian">
                    {t.name}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite">
                    {t.cohort || <span className="italic text-gray-400">General</span>}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite">
                    {new Date(t.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    <span
                      className={`px-2.5 py-0.5 text-xs font-semibold rounded-full ${
                        t.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                      }`}
                    >
                      {t.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm">
                    <button
                      onClick={() => handleViewPerformance(t)}
                      className="px-3 py-1 text-xs font-medium bg-offWhite border border-warmStone text-obsidian rounded hover:border-burntOrange hover:text-burntOrange transition-colors"
                    >
                      View Performance
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Pagination */}
          <div className="px-6 py-4 bg-white border-t border-warmStone flex items-center justify-between">
            <span className="text-sm text-warmGraphite">
              Total {trainees.total} candidates enrolled
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
                Page {page} of {Math.max(1, Math.ceil(trainees.total / 25))}
              </span>
              <button
                onClick={() => setPage((p) => p + 1)}
                disabled={page * 25 >= trainees.total}
                className="px-3 py-1 text-sm border border-warmStone rounded disabled:opacity-40"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Register Trainee Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6 border border-warmStone">
            <h3 className="text-lg font-bold text-obsidian mb-1">Enroll New Trainee</h3>
            <p className="text-xs text-warmGraphite mb-4">
              Enter candidate details to assign diagnostic sensor rigs and track vocational competencies.
            </p>

            {formError && (
              <div className="bg-red-50 text-red-700 text-xs p-3 rounded mb-4 border border-red-200">
                {formError}
              </div>
            )}

            <form onSubmit={handleCreateTrainee} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                  Candidate ID *
                </label>
                <input
                  type="text"
                  placeholder="e.g. TR-2026-001"
                  value={newTraineeId}
                  onChange={(e) => setNewTraineeId(e.target.value)}
                  className="w-full px-3 py-2 border border-warmStone rounded text-sm font-mono focus:outline-none focus:ring-2 focus:ring-burntOrange"
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                  Full Candidate Name *
                </label>
                <input
                  type="text"
                  placeholder="e.g. Ramesh Kumar"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  className="w-full px-3 py-2 border border-warmStone rounded text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                  Assigned Cohort / Batch
                </label>
                <input
                  type="text"
                  placeholder="e.g. Industrial Pipefitting Cohort A"
                  value={newCohort}
                  onChange={(e) => setNewCohort(e.target.value)}
                  className="w-full px-3 py-2 border border-warmStone rounded text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
                />
              </div>

              <div className="flex justify-end gap-3 pt-3 border-t border-warmStone">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 text-sm text-warmGraphite hover:text-obsidian"
                  disabled={isSubmitting}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-4 py-2 text-sm font-medium bg-burntOrange text-white rounded hover:bg-darkBurntOrange transition-colors disabled:opacity-50"
                >
                  {isSubmitting ? 'Registering...' : 'Register Trainee'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Trainee Performance Modal */}
      {selectedTrainee && (
        <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full p-6 border border-warmStone max-h-[85vh] flex flex-col">
            <div className="flex justify-between items-start border-b border-warmStone pb-4 mb-4">
              <div>
                <span className="text-xs font-mono font-bold text-burntOrange uppercase">
                  Candidate Dossier
                </span>
                <h3 className="text-xl font-bold text-obsidian">{selectedTrainee.name}</h3>
                <p className="text-xs text-warmGraphite">
                  ID: <span className="font-mono">{selectedTrainee.trainee_id}</span> • Cohort:{' '}
                  {selectedTrainee.cohort || 'General'}
                </p>
              </div>
              <button
                onClick={() => setSelectedTrainee(null)}
                className="text-warmGraphite hover:text-obsidian text-lg font-bold"
              >
                ✕
              </button>
            </div>

            <div className="overflow-y-auto space-y-6 pr-1">
              {isLoadingHistory ? (
                <div className="py-8 text-center text-warmGraphite text-sm">
                  Loading performance records...
                </div>
              ) : (
                <>
                  {/* Summary Metric Strip */}
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                    <div className="p-3 bg-offWhite rounded border border-warmStone">
                      <div className="text-xs text-warmGraphite uppercase">Diagnostic Sessions</div>
                      <div className="text-2xl font-bold font-mono text-obsidian">
                        {traineeSessions.length}
                      </div>
                    </div>
                    <div className="p-3 bg-offWhite rounded border border-warmStone">
                      <div className="text-xs text-warmGraphite uppercase">Formal Evaluations</div>
                      <div className="text-2xl font-bold font-mono text-burntOrange">
                        {traineeAssessments.length}
                      </div>
                    </div>
                    <div className="p-3 bg-offWhite rounded border border-warmStone col-span-2 sm:col-span-1">
                      <div className="text-xs text-warmGraphite uppercase">Competency Ratio</div>
                      <div className="text-2xl font-bold font-mono text-obsidian">
                        {traineeAssessments.length > 0
                          ? `${Math.round(
                              (traineeAssessments.filter((a) => a.outcome === 'competent').length /
                                traineeAssessments.length) *
                                100
                            )}%`
                          : 'N/A'}
                      </div>
                    </div>
                  </div>

                  {/* Sessions Section */}
                  <div>
                    <h4 className="text-xs font-bold text-warmGraphite uppercase tracking-wider mb-2">
                      Recent Diagnostic Runs
                    </h4>
                    {traineeSessions.length === 0 ? (
                      <div className="p-3 bg-offWhite rounded text-xs text-warmGraphite text-center border border-warmStone">
                        No recorded sessions found for this trainee.
                      </div>
                    ) : (
                      <div className="space-y-2">
                        {traineeSessions.map((s) => (
                          <div
                            key={s.id}
                            className="p-3 border border-warmStone rounded bg-white flex justify-between items-center text-xs"
                          >
                            <div>
                              <span className="font-mono font-bold text-obsidian">#{s.session_id}</span>
                              <span className="text-warmGraphite ml-2">Node: {s.device_id}</span>
                            </div>
                            <span className="text-warmGraphite">
                              {new Date(s.started_at).toLocaleString()}
                            </span>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Assessments Section */}
                  <div>
                    <h4 className="text-xs font-bold text-warmGraphite uppercase tracking-wider mb-2">
                      Vocational Rubric Evaluations
                    </h4>
                    {traineeAssessments.length === 0 ? (
                      <div className="p-3 bg-offWhite rounded text-xs text-warmGraphite text-center border border-warmStone">
                        No formal assessments completed yet.
                      </div>
                    ) : (
                      <div className="space-y-2">
                        {traineeAssessments.map((a) => (
                          <div
                            key={a.id}
                            className="p-3 border border-warmStone rounded bg-white flex justify-between items-center text-xs"
                          >
                            <div>
                              <span className="font-mono font-bold text-obsidian">
                                {a.assessment_id}
                              </span>
                              <span className="text-warmGraphite ml-2">Rubric: {a.rubric_id}</span>
                            </div>
                            <div className="flex items-center gap-2">
                              {a.score !== null && (
                                <span className="font-mono font-bold text-obsidian">
                                  Score: {a.score}
                                </span>
                              )}
                              <span
                                className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                                  a.outcome === 'competent'
                                    ? 'bg-green-100 text-green-800'
                                    : a.outcome === 'needs_improvement'
                                    ? 'bg-amber-100 text-amber-800'
                                    : 'bg-gray-100 text-gray-800'
                                }`}
                              >
                                {a.outcome.replace('_', ' ')}
                              </span>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </>
              )}
            </div>

            <div className="pt-4 mt-4 border-t border-warmStone flex justify-end">
              <button
                onClick={() => setSelectedTrainee(null)}
                className="px-4 py-2 text-sm bg-warmStone rounded hover:bg-softSand text-obsidian font-medium transition-colors"
              >
                Close Dossier
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
