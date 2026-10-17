import { useState, useEffect } from 'react';
import { apiClient } from '../api/client';
import type { Assessment, AssessmentRubric, PaginatedResponse } from '../types';

export default function Assessments() {
  const [assessments, setAssessments] = useState<PaginatedResponse<Assessment> | null>(null);
  const [rubrics, setRubrics] = useState<AssessmentRubric[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [traineeFilter, setTraineeFilter] = useState('');
  const [outcomeFilter, setOutcomeFilter] = useState('');
  const [page, setPage] = useState(1);

  // Tabs: 'evaluations' | 'rubrics'
  const [activeTab, setActiveTab] = useState<'evaluations' | 'rubrics'>('evaluations');

  // Review & Detail Modal
  const [selectedAssessment, setSelectedAssessment] = useState<Assessment | null>(null);
  const [reviewComments, setReviewComments] = useState('');
  const [overrideScore, setOverrideScore] = useState<string>('');
  const [overrideOutcome, setOverrideOutcome] = useState<string>('');
  const [isSubmittingReview, setIsSubmittingReview] = useState(false);
  const [reviewError, setReviewError] = useState('');
  const [reviewSuccess, setReviewSuccess] = useState('');

  // Create Assessment Modal
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [newAssessmentId, setNewAssessmentId] = useState('');
  const [newSessionId, setNewSessionId] = useState('');
  const [newRubricId, setNewRubricId] = useState('RUBRIC-LEAK-V1');
  const [newRubricVersion, setNewRubricVersion] = useState('1.0');
  const [newEvidenceIds, setNewEvidenceIds] = useState('');
  const [newScoringExplanation, setNewScoringExplanation] = useState('');
  const [isSubmittingNew, setIsSubmittingNew] = useState(false);
  const [createError, setCreateError] = useState('');

  useEffect(() => {
    loadAssessments();
    loadRubrics();
  }, [page, traineeFilter, outcomeFilter]);

  const loadAssessments = async () => {
    try {
      setIsLoading(true);
      setError('');
      const params: any = { page, page_size: 25 };
      if (traineeFilter.trim()) params.trainee_id = traineeFilter.trim();
      if (outcomeFilter.trim()) params.outcome = outcomeFilter.trim();
      const res = await apiClient.getAssessments(params);
      setAssessments(res);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load assessments');
    } finally {
      setIsLoading(false);
    }
  };

  const loadRubrics = async () => {
    try {
      const res = await apiClient.getRubrics({ page: 1, page_size: 50 });
      setRubrics(res.items);
    } catch (err) {
      console.error('Failed to load rubrics', err);
    }
  };

  const handleOpenReview = (a: Assessment) => {
    setSelectedAssessment(a);
    setReviewComments('');
    setOverrideScore(a.score !== null ? String(a.score) : '');
    setOverrideOutcome(a.outcome);
    setReviewError('');
    setReviewSuccess('');
  };

  const handleSubmitReview = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedAssessment) return;
    if (!reviewComments.trim()) {
      setReviewError('Trainer review comments are required');
      return;
    }
    try {
      setIsSubmittingReview(true);
      setReviewError('');
      setReviewSuccess('');
      await apiClient.reviewAssessment(selectedAssessment.assessment_id, {
        comments: reviewComments.trim(),
        override_score: overrideScore !== '' ? Number(overrideScore) : undefined,
        override_outcome: overrideOutcome || undefined,
      });
      setReviewSuccess('Trainer review logged and assessment updated.');
      await loadAssessments();
      setTimeout(() => {
        setSelectedAssessment(null);
      }, 1200);
    } catch (err: any) {
      setReviewError(err.response?.data?.detail || 'Failed to submit trainer review');
    } finally {
      setIsSubmittingReview(false);
    }
  };

  const handleCreateAssessment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAssessmentId.trim() || !newSessionId.trim() || !newRubricId.trim()) {
      setCreateError('Assessment ID, Session ID, and Rubric are required');
      return;
    }
    const evidenceList = newEvidenceIds
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s.length > 0)
      .map((s) => Number(s))
      .filter((n) => !isNaN(n));

    try {
      setIsSubmittingNew(true);
      setCreateError('');
      await apiClient.createAssessment({
        assessment_id: newAssessmentId.trim().toUpperCase(),
        session_id: Number(newSessionId),
        rubric_id: newRubricId.trim(),
        rubric_version: newRubricVersion.trim() || '1.0',
        evidence_event_ids: evidenceList,
        scoring_explanation: newScoringExplanation.trim() || undefined,
      });
      setIsCreateModalOpen(false);
      setNewAssessmentId('');
      setNewSessionId('');
      setNewEvidenceIds('');
      setNewScoringExplanation('');
      await loadAssessments();
    } catch (err: any) {
      setCreateError(err.response?.data?.detail || 'Failed to initialize assessment');
    } finally {
      setIsSubmittingNew(false);
    }
  };

  const getOutcomeBadge = (outcome: string) => {
    switch (outcome.toLowerCase()) {
      case 'competent':
        return <span className="px-2.5 py-0.5 text-xs font-bold bg-green-100 text-green-800 rounded-full">COMPETENT</span>;
      case 'needs_improvement':
        return <span className="px-2.5 py-0.5 text-xs font-bold bg-amber-100 text-amber-800 rounded-full">NEEDS IMPROVEMENT</span>;
      default:
        return <span className="px-2.5 py-0.5 text-xs font-bold bg-gray-100 text-gray-800 rounded-full">NOT ASSESSABLE</span>;
    }
  };

  return (
    <div>
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6">
        <div>
          <h2 className="text-2xl font-bold text-obsidian tracking-tight">Vocational Assessments</h2>
          <p className="text-sm text-warmGraphite">
            Diagnostic session evaluations mapped to skilled trades competency rubrics
          </p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={() => setIsCreateModalOpen(true)}
            className="px-4 py-2 text-sm font-medium bg-burntOrange text-white rounded hover:bg-darkBurntOrange transition-colors shadow-sm"
          >
            + Create Evaluation
          </button>
          <button
            onClick={() => {
              loadAssessments();
              loadRubrics();
            }}
            className="px-3 py-1.5 text-sm bg-white border border-warmStone rounded hover:bg-softSand text-obsidian transition-colors"
          >
            Refresh
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-warmStone mb-6">
        <button
          onClick={() => setActiveTab('evaluations')}
          className={`py-2 px-4 text-sm font-semibold border-b-2 transition-colors ${
            activeTab === 'evaluations'
              ? 'border-burntOrange text-burntOrange'
              : 'border-transparent text-warmGraphite hover:text-obsidian'
          }`}
        >
          Session Evaluations
        </button>
        <button
          onClick={() => setActiveTab('rubrics')}
          className={`py-2 px-4 text-sm font-semibold border-b-2 transition-colors ${
            activeTab === 'rubrics'
              ? 'border-burntOrange text-burntOrange'
              : 'border-transparent text-warmGraphite hover:text-obsidian'
          }`}
        >
          Competency Rubrics ({rubrics.length})
        </button>
      </div>

      {activeTab === 'evaluations' ? (
        <>
          {/* Filter Bar */}
          <div className="bg-white rounded-lg shadow-sm p-4 mb-6 border border-warmStone flex flex-col sm:flex-row gap-4">
            <input
              type="text"
              placeholder="Filter by Trainee ID..."
              value={traineeFilter}
              onChange={(e) => {
                setTraineeFilter(e.target.value);
                setPage(1);
              }}
              className="flex-1 px-3 py-2 border border-warmStone rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
            />
            <select
              value={outcomeFilter}
              onChange={(e) => {
                setOutcomeFilter(e.target.value);
                setPage(1);
              }}
              className="w-full sm:w-64 px-3 py-2 border border-warmStone rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
            >
              <option value="">All Outcomes</option>
              <option value="competent">Competent</option>
              <option value="needs_improvement">Needs Improvement</option>
              <option value="not_assessable">Not Assessable</option>
            </select>
          </div>

          {/* Evaluations Table */}
          {isLoading ? (
            <div className="text-warmGraphite py-12 text-center">Loading assessment records...</div>
          ) : error ? (
            <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded mb-6">{error}</div>
          ) : !assessments || assessments.items.length === 0 ? (
            <div className="bg-white rounded-lg shadow-sm p-12 border border-warmStone text-center">
              <div className="w-12 h-12 mx-auto mb-3 rounded-full bg-softSand/50 flex items-center justify-center text-warmGraphite">
                📋
              </div>
              <h3 className="text-lg font-semibold text-obsidian mb-1">No Assessments On Record</h3>
              <p className="text-sm text-warmGraphite max-w-md mx-auto mb-6">
                No session evaluations have been logged yet. Create an assessment from an active or archived diagnostic session to evaluate vocational performance.
              </p>
              <button
                onClick={() => setIsCreateModalOpen(true)}
                className="px-4 py-2 text-sm font-medium bg-burntOrange text-white rounded hover:bg-darkBurntOrange transition-colors"
              >
                Create First Evaluation
              </button>
            </div>
          ) : (
            <div className="bg-white rounded-lg shadow-sm border border-warmStone overflow-hidden">
              <table className="min-w-full divide-y divide-warmStone">
                <thead className="bg-warmStone/60">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                      Evaluation ID
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                      Trainee
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                      Session
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                      Rubric
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                      Score
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                      Outcome
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-semibold text-warmGraphite uppercase tracking-wider">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-warmStone">
                  {assessments.items.map((a) => (
                    <tr key={a.id} className="hover:bg-softSand/20 transition-colors">
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-mono font-bold text-obsidian">
                        {a.assessment_id}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-burntOrange">
                        {a.trainee_id}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-mono text-warmGraphite">
                        #{a.session_id}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-warmGraphite">
                        {a.rubric_id} <span className="text-xs text-gray-400">v{a.rubric_version}</span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-mono font-bold text-obsidian">
                        {a.score !== null ? `${a.score} / ${a.max_score || 100}` : 'Pending'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        {getOutcomeBadge(a.outcome)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-right text-sm">
                        <button
                          onClick={() => handleOpenReview(a)}
                          className="px-3 py-1 text-xs font-medium bg-offWhite border border-warmStone text-obsidian rounded hover:border-burntOrange hover:text-burntOrange transition-colors"
                        >
                          Review & Override
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              {/* Pagination */}
              <div className="px-6 py-4 bg-white border-t border-warmStone flex items-center justify-between">
                <span className="text-sm text-warmGraphite">
                  Total {assessments.total} evaluation records
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
                    Page {page} of {Math.max(1, Math.ceil(assessments.total / 25))}
                  </span>
                  <button
                    onClick={() => setPage((p) => p + 1)}
                    disabled={page * 25 >= assessments.total}
                    className="px-3 py-1 text-sm border border-warmStone rounded disabled:opacity-40"
                  >
                    Next
                  </button>
                </div>
              </div>
            </div>
          )}
        </>
      ) : (
        /* Rubrics Catalog */
        <div className="space-y-4">
          {rubrics.length === 0 ? (
            <div className="p-8 bg-white border border-warmStone rounded-lg text-center text-warmGraphite">
              No rubrics registered yet. Default NSQF competency rules will be loaded from the backend specification.
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {rubrics.map((r) => (
                <div key={r.id} className="p-5 bg-white border border-warmStone rounded-lg shadow-sm">
                  <div className="flex justify-between items-start mb-2">
                    <span className="text-xs font-mono font-bold text-burntOrange uppercase">
                      {r.rubric_id} (v{r.version})
                    </span>
                    <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-green-100 text-green-800">
                      ACTIVE
                    </span>
                  </div>
                  <h4 className="text-base font-bold text-obsidian mb-1">{r.name}</h4>
                  <p className="text-xs text-warmGraphite mb-4">{r.description || 'Standard trade rubric'}</p>

                  <div className="border-t border-warmStone pt-3">
                    <span className="text-[10px] uppercase font-bold text-warmGraphite tracking-wider block mb-2">
                      Scoring Rules / Competency Thresholds:
                    </span>
                    <pre className="text-xs font-mono bg-offWhite p-3 rounded overflow-x-auto text-obsidian border border-warmStone">
                      {JSON.stringify(r.rules, null, 2)}
                    </pre>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Review Modal */}
      {selectedAssessment && (
        <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-lg w-full p-6 border border-warmStone">
            <h3 className="text-lg font-bold text-obsidian mb-1">Trainer Review & Evidence Audit</h3>
            <p className="text-xs text-warmGraphite mb-4">
              Evaluation: <span className="font-mono font-bold">{selectedAssessment.assessment_id}</span> • Trainee:{' '}
              <span className="font-bold text-burntOrange">{selectedAssessment.trainee_id}</span>
            </p>

            {reviewError && (
              <div className="bg-red-50 text-red-700 text-xs p-3 rounded mb-4 border border-red-200">
                {reviewError}
              </div>
            )}
            {reviewSuccess && (
              <div className="bg-green-50 text-green-700 text-xs p-3 rounded mb-4 border border-green-200">
                {reviewSuccess}
              </div>
            )}

            <div className="space-y-3 mb-4 text-xs bg-offWhite p-3 rounded border border-warmStone">
              <div>
                <span className="font-bold text-warmGraphite">Linked Session ID:</span>{' '}
                <span className="font-mono">#{selectedAssessment.session_id}</span>
              </div>
              <div>
                <span className="font-bold text-warmGraphite">Evidence Event IDs:</span>{' '}
                <span className="font-mono">
                  {selectedAssessment.evidence_event_ids && selectedAssessment.evidence_event_ids.length > 0
                    ? selectedAssessment.evidence_event_ids.join(', ')
                    : 'None provided'}
                </span>
              </div>
              <div>
                <span className="font-bold text-warmGraphite">Scoring Explanation:</span>{' '}
                <span>{selectedAssessment.scoring_explanation || 'Pending trainer verification'}</span>
              </div>
            </div>

            <form onSubmit={handleSubmitReview} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                  Trainer Comments / Verification Notes *
                </label>
                <textarea
                  rows={3}
                  placeholder="Record qualitative feedback, observed probe technique, or reason for override..."
                  value={reviewComments}
                  onChange={(e) => setReviewComments(e.target.value)}
                  className="w-full px-3 py-2 border border-warmStone rounded text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                    Score Override
                  </label>
                  <input
                    type="number"
                    step="0.1"
                    placeholder="e.g. 85.0"
                    value={overrideScore}
                    onChange={(e) => setOverrideScore(e.target.value)}
                    className="w-full px-3 py-2 border border-warmStone rounded text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                    Outcome Override
                  </label>
                  <select
                    value={overrideOutcome}
                    onChange={(e) => setOverrideOutcome(e.target.value)}
                    className="w-full px-3 py-2 border border-warmStone rounded text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
                  >
                    <option value="competent">Competent</option>
                    <option value="needs_improvement">Needs Improvement</option>
                    <option value="not_assessable">Not Assessable</option>
                  </select>
                </div>
              </div>

              <div className="flex justify-end gap-3 pt-3 border-t border-warmStone">
                <button
                  type="button"
                  onClick={() => setSelectedAssessment(null)}
                  className="px-4 py-2 text-sm text-warmGraphite hover:text-obsidian"
                  disabled={isSubmittingReview}
                >
                  Close
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingReview}
                  className="px-4 py-2 text-sm font-medium bg-burntOrange text-white rounded hover:bg-darkBurntOrange transition-colors disabled:opacity-50"
                >
                  {isSubmittingReview ? 'Logging...' : 'Save Trainer Review'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Create Evaluation Modal */}
      {isCreateModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6 border border-warmStone">
            <h3 className="text-lg font-bold text-obsidian mb-1">Create Session Evaluation</h3>
            <p className="text-xs text-warmGraphite mb-4">
              Bind a recorded diagnostic run to a vocational assessment rubric.
            </p>

            {createError && (
              <div className="bg-red-50 text-red-700 text-xs p-3 rounded mb-4 border border-red-200">
                {createError}
              </div>
            )}

            <form onSubmit={handleCreateAssessment} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                  Evaluation ID *
                </label>
                <input
                  type="text"
                  placeholder="e.g. EVAL-2026-001"
                  value={newAssessmentId}
                  onChange={(e) => setNewAssessmentId(e.target.value)}
                  className="w-full px-3 py-2 border border-warmStone rounded text-sm font-mono focus:outline-none focus:ring-2 focus:ring-burntOrange"
                  required
                />
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                    Session ID *
                  </label>
                  <input
                    type="number"
                    placeholder="e.g. 1"
                    value={newSessionId}
                    onChange={(e) => setNewSessionId(e.target.value)}
                    className="w-full px-3 py-2 border border-warmStone rounded text-sm font-mono focus:outline-none focus:ring-2 focus:ring-burntOrange"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                    Rubric ID *
                  </label>
                  <select
                    value={newRubricId}
                    onChange={(e) => {
                      setNewRubricId(e.target.value);
                      const matching = rubrics.find((r) => r.rubric_id === e.target.value);
                      if (matching) setNewRubricVersion(matching.version);
                    }}
                    className="w-full px-3 py-2 border border-warmStone rounded text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
                  >
                    {rubrics.length > 0 ? (
                      rubrics.map((r) => (
                        <option key={r.id} value={r.rubric_id}>
                          {r.rubric_id}
                        </option>
                      ))
                    ) : (
                      <option value="RUBRIC-LEAK-V1">RUBRIC-LEAK-V1</option>
                    )}
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                    Version
                  </label>
                  <input
                    type="text"
                    value={newRubricVersion}
                    onChange={(e) => setNewRubricVersion(e.target.value)}
                    className="w-full px-3 py-2 border border-warmStone rounded text-sm font-mono focus:outline-none focus:ring-2 focus:ring-burntOrange"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                  Evidence Event IDs (comma-separated)
                </label>
                <input
                  type="text"
                  placeholder="e.g. 101, 104, 108"
                  value={newEvidenceIds}
                  onChange={(e) => setNewEvidenceIds(e.target.value)}
                  className="w-full px-3 py-2 border border-warmStone rounded text-sm font-mono focus:outline-none focus:ring-2 focus:ring-burntOrange"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-warmGraphite mb-1 uppercase tracking-wider">
                  Scoring Explanation / Scope
                </label>
                <input
                  type="text"
                  placeholder="e.g. Ultrasonic acoustic pipe inspection trial run"
                  value={newScoringExplanation}
                  onChange={(e) => setNewScoringExplanation(e.target.value)}
                  className="w-full px-3 py-2 border border-warmStone rounded text-sm focus:outline-none focus:ring-2 focus:ring-burntOrange"
                />
              </div>

              <div className="flex justify-end gap-3 pt-3 border-t border-warmStone">
                <button
                  type="button"
                  onClick={() => setIsCreateModalOpen(false)}
                  className="px-4 py-2 text-sm text-warmGraphite hover:text-obsidian"
                  disabled={isSubmittingNew}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingNew}
                  className="px-4 py-2 text-sm font-medium bg-burntOrange text-white rounded hover:bg-darkBurntOrange transition-colors disabled:opacity-50"
                >
                  {isSubmittingNew ? 'Creating...' : 'Initialize Evaluation'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
