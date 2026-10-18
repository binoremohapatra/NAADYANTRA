export interface Device {
  id: number;
  device_id: string;
  name: string | null;
  firmware_version: string | null;
  last_seen_at: string | null;
  last_telemetry_at?: string | null;
  device_metadata: Record<string, any>;
  created_at: string;
  is_active: boolean;
  is_online?: boolean;
}

export interface DeviceStatus {
  device_id: string;
  is_registered?: boolean;
  is_active?: boolean;
  last_seen_at: string | null;
  last_telemetry_at?: string | null;
  firmware_version: string | null;
  is_online: boolean;
  has_data?: boolean;
  is_stale?: boolean;
  staleness_seconds?: number;
  recent_activity_count: number;
  last_error: string | null;
}

export interface LatestTelemetryResponse {
  has_data: boolean;
  is_stale: boolean;
  staleness_seconds: number;
  event: Event | null;
}

export interface DeviceKeyRotateResponse {
  device_id: string;
  device_key: string;
  message: string;
}

export interface Event {
  id: number;
  device_id: string;
  session_id: number;
  internal_session_id?: number;
  trainee_id: string;
  event_kind: string;
  device_timestamp: number | null;
  server_timestamp: string;
  device_uptime_ms: number | null;
  event_name: string | null;
  alert: string | null;
  cause: string | null;
  model_label: string | null;
  leak_probability: number | null;
  rms: number | null;
  gas_delta: number | null;
  gas_ratio: number | null;
  temperature: number | null;
  uv_delta: number | null;
  distance_mm?: number | null;
  battery_v?: number | null;
  wet: boolean | null;
  firmware_version?: string | null;
  raw_payload?: Record<string, any>;
  ingestion_status?: string;
}

export interface Session {
  id: number;
  session_id: number;
  device_id: string;
  trainee_id: string;
  started_at: string;
  ended_at: string | null;
  trainer_notes?: string | null;
  session_metadata: Record<string, any>;
  created_at: string;
}

export interface SessionSummary {
  id: number;
  session_id: number;
  device_session_id: number;
  device_id: string;
  trainee_id: string;
  duration_seconds: number | null;
  windows: number | null;
  leak_events: number | null;
  gas_events: number | null;
  wet_events: number | null;
  heat_events: number | null;
  uv_events: number | null;
  noise_windows: number | null;
  max_leak_probability: number | null;
  firmware_version: string | null;
  server_timestamp: string;
}

export interface DashboardOverview {
  total_sessions: number;
  total_devices: number;
  total_trainees: number;
  total_events: number;
  recent_sessions_count: number;
  active_devices_count: number;
  online_devices_count?: number;
  offline_devices_count?: number;
  stale_devices_count?: number;
  never_reported_count?: number;
  alert_events_count?: number;
  recent_ingestion_failures_count?: number;
  server_utc?: string;
}

export interface PaginatedResponse<T> {
  total: number;
  page: number;
  page_size: number;
  items: T[];
}

export interface DashboardAlert {
  id: number;
  device_id: string;
  trainee_id: string;
  timestamp: string;
  alert: string;
  cause: string;
  details: {
    event_name?: string;
    model_label?: string;
    leak_probability?: number;
    rms?: number;
    gas_delta?: number;
  };
}

export interface Trainee {
  id: number;
  trainee_id: string;
  name: string;
  cohort: string | null;
  trainee_metadata: Record<string, any>;
  is_active: boolean;
  created_at: string;
}

export interface TraineeCreateRequest {
  trainee_id: string;
  name: string;
  cohort?: string;
  trainee_metadata?: Record<string, any>;
}

export interface AssessmentRubric {
  id: number;
  rubric_id: string;
  version: string;
  name: string;
  description: string | null;
  rules: Record<string, any>;
  created_by: string;
  created_at: string;
  is_active: boolean;
}

export interface Assessment {
  id: number;
  assessment_id: string;
  session_id: number;
  trainee_id: string;
  rubric_id: string;
  rubric_version: string;
  evidence_event_ids: number[];
  score: number | null;
  max_score: number | null;
  outcome: string; // 'competent' | 'needs_improvement' | 'not_assessable'
  scoring_explanation: string | null;
  created_by: string;
  created_at: string;
}

export interface TrainerReview {
  id: number;
  assessment_id: string;
  reviewer: string;
  comments: string;
  override_score: number | null;
  override_outcome: string | null;
  created_at: string;
}

export interface AssessmentCreateRequest {
  assessment_id: string;
  session_id: number;
  rubric_id: string;
  rubric_version: string;
  evidence_event_ids: number[];
  scoring_explanation?: string;
}

export interface TrainerReviewRequest {
  comments: string;
  override_score?: number;
  override_outcome?: string;
}

export interface SessionExportResponse {
  content_type: string;
  filename: string;
  data: string;
}
