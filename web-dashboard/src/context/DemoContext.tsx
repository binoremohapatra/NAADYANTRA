import { createContext, useContext, useState, useEffect, type ReactNode } from 'react';
import type {
  Device,
  DeviceStatus,
  Event,
  Session,
  SessionSummary,
  Trainee,
  Assessment,
  AssessmentRubric,
  DashboardOverview,
  LatestTelemetryResponse,
} from '../types';

interface DemoContextType {
  isDemoMode: boolean;
  toggleDemoMode: () => void;
  setDemoMode: (enabled: boolean) => void;
  demoData: {
    overview: DashboardOverview;
    devices: Device[];
    deviceStatuses: Record<string, DeviceStatus>;
    latestTelemetry: Record<string, LatestTelemetryResponse>;
    events: Event[];
    sessions: Session[];
    sessionSummaries: Record<number, SessionSummary>;
    trainees: Trainee[];
    assessments: Assessment[];
    rubrics: AssessmentRubric[];
  };
}

const DEMO_OVERVIEW: DashboardOverview = {
  total_sessions: 24,
  total_devices: 3,
  total_trainees: 12,
  total_events: 1840,
  recent_sessions_count: 5,
  active_devices_count: 2,
  online_devices_count: 1,
  offline_devices_count: 2,
  stale_devices_count: 1,
  never_reported_count: 0,
  alert_events_count: 14,
  recent_ingestion_failures_count: 0,
  server_utc: new Date().toISOString(),
};

const DEMO_DEVICES: Device[] = [
  {
    id: 101,
    device_id: 'SIH-DEV-01',
    name: 'Rig Alpha — Acoustic & Gas Bench',
    firmware_version: '1.1.0',
    last_seen_at: new Date(Date.now() - 8000).toISOString(),
    last_telemetry_at: new Date(Date.now() - 8000).toISOString(),
    device_metadata: {
      location: 'Plumbing Lab Bay 2',
      trade_alignment: 'Plumber PSC/Q0104 Level 4',
      piezo_gain: 35,
      simulated: true,
    },
    created_at: '2026-10-01T08:00:00Z',
    is_active: true,
    is_online: true,
  },
  {
    id: 102,
    device_id: 'SIH-DEV-02',
    name: 'Bench Beta — Refrigeration Training Rig',
    firmware_version: '1.1.0',
    last_seen_at: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
    last_telemetry_at: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
    device_metadata: {
      location: 'HVAC Lab Station 4',
      trade_alignment: 'AC Tech ELE/Q3102 Level 4',
      piezo_gain: 40,
      simulated: true,
    },
    created_at: '2026-10-02T09:30:00Z',
    is_active: true,
    is_online: false,
  },
  {
    id: 103,
    device_id: 'SIH-DEV-03',
    name: 'Portable Kit Gamma — Mechanical Inspection',
    firmware_version: '1.1.0',
    last_seen_at: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString(),
    last_telemetry_at: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString(),
    device_metadata: {
      location: 'Mobile Assessment Kit',
      trade_alignment: 'Fitter CSC/Q0901 Level 3',
      piezo_gain: 25,
      simulated: true,
    },
    created_at: '2026-10-05T11:00:00Z',
    is_active: true,
    is_online: false,
  },
];

const DEMO_DEVICE_STATUSES: Record<string, DeviceStatus> = {
  'SIH-DEV-01': {
    device_id: 'SIH-DEV-01',
    is_registered: true,
    is_active: true,
    last_seen_at: new Date(Date.now() - 8000).toISOString(),
    last_telemetry_at: new Date(Date.now() - 8000).toISOString(),
    firmware_version: '1.1.0',
    is_online: true,
    has_data: true,
    is_stale: false,
    staleness_seconds: 8,
    recent_activity_count: 142,
    last_error: null,
  },
  'SIH-DEV-02': {
    device_id: 'SIH-DEV-02',
    is_registered: true,
    is_active: true,
    last_seen_at: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
    last_telemetry_at: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
    firmware_version: '1.1.0',
    is_online: false,
    has_data: true,
    is_stale: true,
    staleness_seconds: 2700,
    recent_activity_count: 58,
    last_error: null,
  },
  'SIH-DEV-03': {
    device_id: 'SIH-DEV-03',
    is_registered: true,
    is_active: true,
    last_seen_at: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString(),
    last_telemetry_at: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString(),
    firmware_version: '1.1.0',
    is_online: false,
    has_data: true,
    is_stale: true,
    staleness_seconds: 64800,
    recent_activity_count: 0,
    last_error: null,
  },
};

const DEMO_EVENTS: Event[] = [
  {
    id: 9001,
    device_id: 'SIH-DEV-01',
    session_id: 101,
    internal_session_id: 101,
    trainee_id: 'T001',
    event_kind: 'event',
    device_timestamp: Math.floor(Date.now() / 1000) - 15,
    server_timestamp: new Date(Date.now() - 15000).toISOString(),
    device_uptime_ms: 124500,
    event_name: 'leak_alert',
    alert: 'DANGER',
    cause: 'acoustic_elevation',
    model_label: 'leak_detected (rms)',
    leak_probability: 0.88,
    rms: 1845.2,
    gas_delta: 34,
    gas_ratio: 0.91,
    temperature: null,
    uv_delta: null,
    wet: false,
    firmware_version: '1.1.0',
  },
  {
    id: 9002,
    device_id: 'SIH-DEV-01',
    session_id: 101,
    internal_session_id: 101,
    trainee_id: 'T001',
    event_kind: 'event',
    device_timestamp: Math.floor(Date.now() / 1000) - 45,
    server_timestamp: new Date(Date.now() - 45000).toISOString(),
    device_uptime_ms: 94500,
    event_name: 'probe_contact',
    alert: 'CAUTION',
    cause: 'acoustic_elevation',
    model_label: 'leak_suspect (rms)',
    leak_probability: 0.62,
    rms: 1280.0,
    gas_delta: 22,
    gas_ratio: 0.94,
    temperature: null,
    uv_delta: null,
    wet: false,
    firmware_version: '1.1.0',
  },
  {
    id: 9003,
    device_id: 'SIH-DEV-01',
    session_id: 101,
    internal_session_id: 101,
    trainee_id: 'T001',
    event_kind: 'event',
    device_timestamp: Math.floor(Date.now() / 1000) - 90,
    server_timestamp: new Date(Date.now() - 90000).toISOString(),
    device_uptime_ms: 49500,
    event_name: 'baseline_sweep',
    alert: 'OK',
    cause: 'normal_baseline',
    model_label: 'normal_baseline',
    leak_probability: 0.04,
    rms: 412.0,
    gas_delta: 8,
    gas_ratio: 0.98,
    temperature: null,
    uv_delta: null,
    wet: false,
    firmware_version: '1.1.0',
  },
  {
    id: 9004,
    device_id: 'SIH-DEV-02',
    session_id: 102,
    internal_session_id: 102,
    trainee_id: 'T002',
    event_kind: 'event',
    device_timestamp: Math.floor(Date.now() / 1000) - 1000 * 60 * 45,
    server_timestamp: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
    device_uptime_ms: 85200,
    event_name: 'gas_alert',
    alert: 'CAUTION',
    cause: 'combustible_vapor_indicative',
    model_label: 'gas_elevated',
    leak_probability: 0.15,
    rms: 490.0,
    gas_delta: 295,
    gas_ratio: 0.52,
    temperature: null,
    uv_delta: null,
    wet: false,
    firmware_version: '1.1.0',
  },
  {
    id: 9005,
    device_id: 'SIH-DEV-02',
    session_id: 102,
    internal_session_id: 102,
    trainee_id: 'T002',
    event_kind: 'event',
    device_timestamp: Math.floor(Date.now() / 1000) - 1000 * 60 * 47,
    server_timestamp: new Date(Date.now() - 1000 * 60 * 47).toISOString(),
    device_uptime_ms: 65200,
    event_name: 'wet_alert',
    alert: 'CAUTION',
    cause: 'moisture_conduction',
    model_label: 'moisture_detected',
    leak_probability: 0.08,
    rms: 430.0,
    gas_delta: 14,
    gas_ratio: 0.95,
    temperature: null,
    uv_delta: null,
    wet: true,
    firmware_version: '1.1.0',
  },
  {
    id: 9006,
    device_id: 'SIH-DEV-03',
    session_id: 103,
    internal_session_id: 103,
    trainee_id: 'T003',
    event_kind: 'event',
    device_timestamp: Math.floor(Date.now() / 1000) - 1000 * 60 * 60 * 18,
    server_timestamp: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString(),
    device_uptime_ms: 32000,
    event_name: 'session_start',
    alert: 'OK',
    cause: 'session_init',
    model_label: 'nominal',
    leak_probability: 0.02,
    rms: 380.0,
    gas_delta: 5,
    gas_ratio: 0.99,
    temperature: null,
    uv_delta: null,
    wet: false,
    firmware_version: '1.1.0',
  },
];

const DEMO_LATEST_TELEMETRY: Record<string, LatestTelemetryResponse> = {
  'SIH-DEV-01': {
    has_data: true,
    is_stale: false,
    staleness_seconds: 15,
    event: DEMO_EVENTS[0],
  },
  'SIH-DEV-02': {
    has_data: true,
    is_stale: true,
    staleness_seconds: 2700,
    event: DEMO_EVENTS[3],
  },
  'SIH-DEV-03': {
    has_data: true,
    is_stale: true,
    staleness_seconds: 64800,
    event: DEMO_EVENTS[5],
  },
};

const DEMO_SESSIONS: Session[] = [
  {
    id: 101,
    session_id: 101,
    device_id: 'SIH-DEV-01',
    trainee_id: 'T001',
    started_at: new Date(Date.now() - 1000 * 60 * 8).toISOString(),
    ended_at: new Date(Date.now() - 1000 * 60 * 3).toISOString(),
    trainer_notes: 'Candidate completed multi-point acoustic inspection across 4 pipe joints. Leak localized at joint #3 with high acoustic RMS.',
    session_metadata: {
      trade: 'Plumber (General)',
      qualification_pack: 'PSC/Q0104 Level 4',
      rubric_id: 'RUBRIC-LEAK-V1',
      simulated: true,
    },
    created_at: new Date(Date.now() - 1000 * 60 * 8).toISOString(),
  },
  {
    id: 102,
    session_id: 102,
    device_id: 'SIH-DEV-02',
    trainee_id: 'T002',
    started_at: new Date(Date.now() - 1000 * 60 * 52).toISOString(),
    ended_at: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
    trainer_notes: 'Refrigerant line check with pre-inspection atmospheric sweep. Indicative vapor delta observed; pipe sweat moisture flagged.',
    session_metadata: {
      trade: 'Field Technician - AC',
      qualification_pack: 'ELE/Q3102 Level 4',
      rubric_id: 'RUBRIC-HAZARD-V1',
      simulated: true,
    },
    created_at: new Date(Date.now() - 1000 * 60 * 52).toISOString(),
  },
  {
    id: 103,
    session_id: 103,
    device_id: 'SIH-DEV-03',
    trainee_id: 'T003',
    started_at: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString(),
    ended_at: null, // Active
    trainer_notes: 'Mechanical fitting fluid coupling integrity exercise.',
    session_metadata: {
      trade: 'Fitter - Mechanical Assembly',
      qualification_pack: 'CSC/Q0901 Level 3',
      rubric_id: 'RUBRIC-LEAK-V1',
      simulated: true,
    },
    created_at: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString(),
  },
];

const DEMO_SUMMARIES: Record<number, SessionSummary> = {
  101: {
    id: 201,
    session_id: 101,
    device_session_id: 101,
    device_id: 'SIH-DEV-01',
    trainee_id: 'T001',
    duration_seconds: 300,
    windows: 30,
    leak_events: 3,
    gas_events: 0,
    wet_events: 0,
    heat_events: 0,
    uv_events: 0,
    noise_windows: 2,
    max_leak_probability: 0.88,
    firmware_version: '1.1.0',
    server_timestamp: new Date(Date.now() - 1000 * 60 * 3).toISOString(),
  },
  102: {
    id: 202,
    session_id: 102,
    device_session_id: 102,
    device_id: 'SIH-DEV-02',
    trainee_id: 'T002',
    duration_seconds: 420,
    windows: 42,
    leak_events: 1,
    gas_events: 2,
    wet_events: 1,
    heat_events: 0,
    uv_events: 0,
    noise_windows: 4,
    max_leak_probability: 0.65,
    firmware_version: '1.1.0',
    server_timestamp: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
  },
};

const DEMO_TRAINEES: Trainee[] = [
  {
    id: 301,
    trainee_id: 'T001',
    name: 'Rahul Sharma',
    cohort: 'ITI-PLUMB-2026-A',
    trainee_metadata: {
      trade: 'Plumber (General)',
      qp_code: 'PSC/Q0104',
      center: 'Govt ITI Pusa, New Delhi',
      simulated: true,
    },
    is_active: true,
    created_at: '2026-09-15T09:00:00Z',
  },
  {
    id: 302,
    trainee_id: 'T002',
    name: 'Priya Patel',
    cohort: 'ITI-HVAC-2026-B',
    trainee_metadata: {
      trade: 'Field Technician - AC',
      qp_code: 'ELE/Q3102',
      center: 'Govt ITI Kubernagar, Ahmedabad',
      simulated: true,
    },
    is_active: true,
    created_at: '2026-09-18T10:00:00Z',
  },
  {
    id: 303,
    trainee_id: 'T003',
    name: 'Amit Kumar',
    cohort: 'ITI-FITTER-2026-A',
    trainee_metadata: {
      trade: 'Fitter - Mechanical Assembly',
      qp_code: 'CSC/Q0901',
      center: 'Govt ITI Durgapur, West Bengal',
      simulated: true,
    },
    is_active: true,
    created_at: '2026-09-20T11:00:00Z',
  },
];

const DEMO_RUBRICS: AssessmentRubric[] = [
  {
    id: 401,
    rubric_id: 'RUBRIC-LEAK-V1',
    version: '1.0',
    name: 'Pressurized Piping Acoustic Leak Diagnosis',
    description: 'Aligned to Plumber PSC/Q0104 Level 4 & AC Tech ELE/Q3102 Level 4. Evaluates baseline calibration, probe coupling, multi-point comparative localization, and protocol hygiene.',
    rules: {
      trade_alignment: 'Plumber (General - Level 4) / Field Technician - AC (Level 4)',
      passing_score: 75.0,
      max_score: 100.0,
      criteria: [
        { code: 'CRIT-01', title: 'Baseline Ambient Calibration', weight: 20.0, rule: '>= 10 clean baseline windows (RMS < 600 counts) before testing active joints.' },
        { code: 'CRIT-02', title: 'Probe Coupling & Signal Integrity', weight: 30.0, rule: 'Steady contact probe coupling without dropout (RMS > 0.8 counts).' },
        { code: 'CRIT-03', title: 'Leak Identification & Triage', weight: 35.0, rule: 'Localize micro-fissure; trigger acoustic elevation confirmed across >= 2 consecutive windows.' },
        { code: 'CRIT-04', title: 'Inspection Hygiene & Session Closure', weight: 15.0, rule: 'Proper closure via BOOT button; session duration >= 60 seconds.' },
      ],
    },
    created_by: 'system_curriculum_audit',
    created_at: '2026-10-17T08:00:00Z',
    is_active: true,
  },
  {
    id: 402,
    rubric_id: 'RUBRIC-HAZARD-V1',
    version: '1.0',
    name: 'Pre-Inspection Multi-Hazard Sweep',
    description: 'Educational situational awareness sweep for combustible vapor delta (MQ-2) and moisture pooling before physical tool engagement.',
    rules: {
      trade_alignment: 'Multi-Trade Hazardous Environment Awareness',
      passing_score: 75.0,
      max_score: 100.0,
      criteria: [
        { code: 'CRIT-01', title: 'Pre-Work Environmental Sweep', weight: 30.0, rule: 'Perform 10s atmospheric sweep before probe placement.' },
        { code: 'CRIT-02', title: 'Combustible Vapor Delta Awareness', weight: 30.0, rule: 'Identify relative gas delta elevation (Rs/R0 < 0.60).' },
        { code: 'CRIT-03', title: 'Moisture / Liquid Contact Check', weight: 20.0, rule: 'Check pipe sweat to prevent probe short-circuit.' },
        { code: 'CRIT-04', title: 'Hazard Reporting & Safe Abort', weight: 20.0, rule: 'Immediately withdraw probe if alert triggered.' },
      ],
    },
    created_by: 'system_curriculum_audit',
    created_at: '2026-10-17T08:30:00Z',
    is_active: true,
  },
];

const DEMO_ASSESSMENTS: Assessment[] = [
  {
    id: 501,
    assessment_id: 'ASM-DEMO-001',
    session_id: 101,
    trainee_id: 'T001',
    rubric_id: 'RUBRIC-LEAK-V1',
    rubric_version: '1.0',
    evidence_event_ids: [9001, 9002, 9003],
    score: 88.0,
    max_score: 100.0,
    outcome: 'competent',
    scoring_explanation: 'Candidate Rahul Sharma demonstrated methodical multi-point inspection. Satisfied CRIT-01 baseline calibration (12 windows, avg RMS 412). Maintained steady acoustic coupling (CRIT-02). Localized pipe joint #3 leak across 3 sustained windows (RMS 1845.2, leak P 0.88) (CRIT-03). Clean session closure (CRIT-04).',
    created_by: 'trainer_lead',
    created_at: new Date(Date.now() - 1000 * 60 * 2).toISOString(),
  },
  {
    id: 502,
    assessment_id: 'ASM-DEMO-002',
    session_id: 102,
    trainee_id: 'T002',
    rubric_id: 'RUBRIC-HAZARD-V1',
    rubric_version: '1.0',
    evidence_event_ids: [9004, 9005],
    score: 62.0,
    max_score: 100.0,
    outcome: 'needs_improvement',
    scoring_explanation: 'Candidate Priya Patel skipped the mandatory 10-second ambient baseline sweep prior to probe contact; placed probe prematurely before reading stabilized. Moisture detection correctly identified.',
    created_by: 'trainer_lead',
    created_at: new Date(Date.now() - 1000 * 60 * 35).toISOString(),
  },
];

const DemoContext = createContext<DemoContextType | undefined>(undefined);

export function DemoProvider({ children }: { children: ReactNode }) {
  const [isDemoMode, setIsDemoMode] = useState<boolean>(() => {
    return localStorage.getItem('hg_demo_mode') === 'true';
  });

  useEffect(() => {
    localStorage.setItem('hg_demo_mode', String(isDemoMode));
  }, [isDemoMode]);

  const toggleDemoMode = () => {
    setIsDemoMode((prev) => !prev);
  };

  const setDemoMode = (enabled: boolean) => {
    setIsDemoMode(enabled);
  };

  return (
    <DemoContext.Provider
      value={{
        isDemoMode,
        toggleDemoMode,
        setDemoMode,
        demoData: {
          overview: DEMO_OVERVIEW,
          devices: DEMO_DEVICES,
          deviceStatuses: DEMO_DEVICE_STATUSES,
          latestTelemetry: DEMO_LATEST_TELEMETRY,
          events: DEMO_EVENTS,
          sessions: DEMO_SESSIONS,
          sessionSummaries: DEMO_SUMMARIES,
          trainees: DEMO_TRAINEES,
          assessments: DEMO_ASSESSMENTS,
          rubrics: DEMO_RUBRICS,
        },
      }}
    >
      {children}
    </DemoContext.Provider>
  );
}

export function useDemo() {
  const context = useContext(DemoContext);
  if (!context) {
    throw new Error('useDemo must be used within a DemoProvider');
  }
  return context;
}
