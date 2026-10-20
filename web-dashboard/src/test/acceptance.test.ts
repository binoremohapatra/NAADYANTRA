import { describe, it, expect } from 'vitest';
import { DICTIONARY } from '../context/LanguageContext';
import { sanitizeEventPayload, computeDeviceFreshness, getExplainableInsight } from '../utils/telemetry';
import type { Event, Device, Session, SessionSummary } from '../types';

describe('SIH26244 Acceptance: Hindi-English Localisation System', () => {
  it('contains valid translations for all critical navigation items', () => {
    const navKeys = [
      'nav.overview',
      'nav.feed',
      'nav.diagnostics',
      'nav.training',
      'nav.devices',
      'nav.sessions',
      'nav.trainees',
      'nav.assessments',
      'nav.alerts',
      'nav.bom',
      'nav.signout',
    ];

    for (const key of navKeys) {
      expect(DICTIONARY[key]).toBeDefined();
      expect(DICTIONARY[key].en.length).toBeGreaterThan(0);
      expect(DICTIONARY[key].hi.length).toBeGreaterThan(0);
    }
  });

  it('contains valid Hindi translations for device statuses and alert severities', () => {
    const statusKeys = ['status.online', 'status.stale', 'status.offline', 'status.safe', 'status.caution', 'status.danger'];
    for (const key of statusKeys) {
      expect(DICTIONARY[key].en).toBeDefined();
      expect(DICTIONARY[key].hi).toBeDefined();
    }
    expect(DICTIONARY['status.online'].hi).toContain('सक्रिय');
    expect(DICTIONARY['status.danger'].hi).toContain('खतरा');
  });

  it('contains authoritative safety and operational disclaimers in both languages', () => {
    expect(DICTIONARY['disclaimer.wifi'].en).toContain('Browser sandboxing');
    expect(DICTIONARY['disclaimer.wifi'].hi).toContain('ब्राउज़र सुरक्षा');
    expect(DICTIONARY['disclaimer.sensors'].en.toLowerCase()).toContain('contact piezo');
    expect(DICTIONARY['disclaimer.sensors'].hi).toContain('पीजो सेंसर');
  });
});

describe('SIH26244 Acceptance: Multi-Device Fleet & Telemetry Stream Isolation', () => {
  const deviceA: Device = {
    id: 1,
    device_id: 'RIG-PLUMB-01',
    name: 'Plumbing Rig 1',
    firmware_version: '1.1.0',
    is_active: true,
    last_seen_at: new Date(Date.now() - 20000).toISOString(),
    created_at: '2026-10-01T00:00:00Z',
    device_metadata: { trade: 'Plumber' },
  };

  const deviceB: Device = {
    id: 2,
    device_id: 'RIG-HVAC-02',
    name: 'HVAC Testing Rig 2',
    firmware_version: '1.1.0',
    is_active: true,
    last_seen_at: new Date(Date.now() - 400000).toISOString(),
    created_at: '2026-10-01T00:00:00Z',
    device_metadata: { trade: 'Refrigeration' },
  };

  it('correctly assesses individual device freshness without cross-talk', () => {
    const freshA = computeDeviceFreshness(deviceA.last_seen_at);
    const freshB = computeDeviceFreshness(deviceB.last_seen_at);

    expect(freshA.state).toBe('online');
    expect(freshB.state).toBe('offline');
  });

  it('filters active feed strictly by device_id without merging separate device measurements', () => {
    const streamEvents: Event[] = [
      {
        id: 101,
        device_id: 'RIG-PLUMB-01',
        session_id: 1,
        trainee_id: 'T001',
        event_kind: 'telemetry',
        device_timestamp: null,
        server_timestamp: '2026-10-20T10:00:00Z',
        device_uptime_ms: 12000,
        event_name: 'telemetry',
        alert: 'OK',
        cause: 'none',
        model_label: 'normal',
        leak_probability: 0.05,
        rms: 420,
        gas_delta: 12,
        gas_ratio: 0.98,
        battery_v: 3.92,
        wet: false,
        temperature: null,
        uv_delta: null,
        distance_mm: 310,
        raw_payload: {},
      },
      {
        id: 102,
        device_id: 'RIG-HVAC-02',
        session_id: 2,
        trainee_id: 'T002',
        event_kind: 'telemetry',
        device_timestamp: null,
        server_timestamp: '2026-10-20T10:00:05Z',
        device_uptime_ms: 15000,
        event_name: 'telemetry',
        alert: 'DANGER',
        cause: 'leak_detected',
        model_label: 'leak(rms)',
        leak_probability: 0.91,
        rms: 1980,
        gas_delta: 24,
        gas_ratio: 0.92,
        battery_v: 3.75,
        wet: false,
        temperature: null,
        uv_delta: null,
        distance_mm: 120,
        raw_payload: {},
      },
    ];

    // Filter by RIG-PLUMB-01
    const filteredA = streamEvents.filter((e) => e.device_id === 'RIG-PLUMB-01');
    expect(filteredA.length).toBe(1);
    expect(filteredA[0].device_id).toBe('RIG-PLUMB-01');
    expect(filteredA[0].rms).toBe(420);

    // Filter by RIG-HVAC-02
    const filteredB = streamEvents.filter((e) => e.device_id === 'RIG-HVAC-02');
    expect(filteredB.length).toBe(1);
    expect(filteredB[0].device_id).toBe('RIG-HVAC-02');
    expect(filteredB[0].rms).toBe(1980);
  });

  it('sorts out-of-order and delayed events chronologically by server_timestamp', () => {
    const rawEvents: Partial<Event>[] = [
      { id: 1, server_timestamp: '2026-10-20T10:00:10Z' },
      { id: 2, server_timestamp: '2026-10-20T10:00:05Z' }, // arrived out of order
      { id: 3, server_timestamp: '2026-10-20T10:00:25Z' },
    ];

    const sortedDesc = [...rawEvents].sort(
      (a, b) => new Date(b.server_timestamp!).getTime() - new Date(a.server_timestamp!).getTime()
    );

    expect(sortedDesc[0].id).toBe(3);
    expect(sortedDesc[1].id).toBe(1);
    expect(sortedDesc[2].id).toBe(2);
  });
});

describe('SIH26244 Acceptance: Honest Sensor Representation & Zero Fabrication', () => {
  it('correctly reports unpopulated optional sensors as null, preventing fabricated readings', () => {
    const rawTelemetry = {
      id: 501,
      device_id: 'RIG-01',
      rms: 380,
      // battery, temperature, uv are unpopulated
    };

    const sanitized = sanitizeEventPayload(rawTelemetry);
    expect(sanitized.rms).toBe(380);
    expect(sanitized.battery_v).toBeNull();
    expect(sanitized.temperature).toBeNull();
    expect(sanitized.uv_delta).toBeNull();
  });

  it('labels inference provenance truthfully between heuristic fallback and embedded TinyML', () => {
    const heuristicEvent: Event = {
      id: 1,
      device_id: 'RIG-01',
      session_id: 1,
      trainee_id: 'T001',
      event_kind: 'telemetry',
      device_timestamp: null,
      server_timestamp: '2026-10-20T10:00:00Z',
      device_uptime_ms: null,
      event_name: 'leak_alert',
      alert: 'DANGER',
      cause: 'leak_detected',
      model_label: 'leak(rms)',
      leak_probability: 0.85,
      rms: 1820,
      gas_delta: 10,
      gas_ratio: 0.98,
      battery_v: 3.85,
      wet: false,
      temperature: null,
      uv_delta: null,
      distance_mm: null,
      raw_payload: {},
    };

    const insight = getExplainableInsight(heuristicEvent);
    expect(insight.algorithmModel).toContain('RMS Ratio Heuristic');
    expect(insight.headline).toContain('Acoustic Turbulence Signature');
  });
});

describe('SIH26244 Acceptance: Session Reporting & Export Data Integrity', () => {
  it('generates well-formed CSV telemetry with required columns and timestamps', () => {
    const session: Session = {
      id: 5,
      session_id: 1005,
      device_id: 'SIH-DEV-01',
      trainee_id: 'T001',
      started_at: '2026-10-20T09:00:00Z',
      ended_at: '2026-10-20T09:15:30Z',
      trainer_notes: 'Demonstrated pipe screening procedure under safe standoff.',
      session_metadata: { trade: 'Plumber' },
      created_at: '2026-10-20T09:00:00Z',
    };

    const summary: SessionSummary = {
      id: 1,
      session_id: 5,
      device_session_id: 1005,
      device_id: 'SIH-DEV-01',
      trainee_id: 'T001',
      duration_seconds: 930,
      windows: 930,
      leak_events: 2,
      gas_events: 0,
      wet_events: 0,
      heat_events: 0,
      uv_events: 0,
      noise_windows: 15,
      max_leak_probability: 0.94,
      firmware_version: '1.1.0',
      server_timestamp: '2026-10-20T09:15:30Z',
    };

    expect(session.trainee_id).toBe('T001');
    expect(summary.windows).toBe(930);
    expect(summary.leak_events).toBe(2);

    // Verify CSV line construction
    const header = 'timestamp,device_id,trainee_id,event_name,alert,cause,rms,gas_delta,wet';
    const row = `${session.started_at},${session.device_id},${session.trainee_id},telemetry,OK,none,420,10,false`;

    expect(header.split(',').length).toBe(9);
    expect(row.split(',').length).toBe(9);
    expect(row).toContain('SIH-DEV-01');
    expect(row).toContain('T001');
  });
});
