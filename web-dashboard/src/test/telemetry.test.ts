import { describe, it, expect } from 'vitest';
import {
  computeDeviceFreshness,
  sanitizeEventPayload,
  getExplainableInsight,
} from '../utils/telemetry';
import type { Event } from '../types';

describe('computeDeviceFreshness', () => {
  it('returns unknown for null or empty timestamp', () => {
    expect(computeDeviceFreshness(null).state).toBe('unknown');
    expect(computeDeviceFreshness(undefined).state).toBe('unknown');
    expect(computeDeviceFreshness('').state).toBe('unknown');
    expect(computeDeviceFreshness('not-a-date').state).toBe('unknown');
  });

  it('returns online when last seen is within 60 seconds', () => {
    const recent = new Date(Date.now() - 15 * 1000).toISOString();
    const result = computeDeviceFreshness(recent, 60, 300);
    expect(result.state).toBe('online');
    expect(result.badgeClass).toBe('hg-badge-ok');
    expect(result.secondsAgo).toBeLessThanOrEqual(20);
  });

  it('returns stale when last seen is between 60 and 300 seconds', () => {
    const staleTime = new Date(Date.now() - 120 * 1000).toISOString();
    const result = computeDeviceFreshness(staleTime, 60, 300);
    expect(result.state).toBe('stale');
    expect(result.badgeClass).toBe('hg-badge-caution');
    expect(result.label).toContain('Stale');
  });

  it('returns offline when last seen exceeds 300 seconds', () => {
    const offlineTime = new Date(Date.now() - 600 * 1000).toISOString();
    const result = computeDeviceFreshness(offlineTime, 60, 300);
    expect(result.state).toBe('offline');
    expect(result.badgeClass).toBe('hg-badge-neutral');
    expect(result.label).toContain('Offline');
  });
});

describe('sanitizeEventPayload (Null Safety & Zero Fabrication)', () => {
  it('preserves null for absent optional sensors and never coerces to 0', () => {
    const raw = {
      id: 42,
      device_id: 'RIG-001',
      session_id: 10,
      rms: 1420,
      // temperature, uv_delta, distance_mm are completely missing
    };

    const sanitized = sanitizeEventPayload(raw);
    expect(sanitized.id).toBe(42);
    expect(sanitized.device_id).toBe('RIG-001');
    expect(sanitized.rms).toBe(1420);
    expect(sanitized.temperature).toBeNull();
    expect(sanitized.uv_delta).toBeNull();
    expect(sanitized.distance_mm).toBeNull();
    expect(sanitized.battery_v).toBeNull();
    expect(sanitized.wet).toBeNull();
  });

  it('preserves valid numerical values when present', () => {
    const raw = {
      id: 99,
      device_id: 'RIG-002',
      session_id: 11,
      rms: 750,
      gas_delta: 240,
      gas_ratio: 0.72,
      battery_v: 3.82,
      wet: false,
    };

    const sanitized = sanitizeEventPayload(raw);
    expect(sanitized.gas_delta).toBe(240);
    expect(sanitized.gas_ratio).toBe(0.72);
    expect(sanitized.battery_v).toBe(3.82);
    expect(sanitized.wet).toBe(false);
  });
});

describe('getExplainableInsight', () => {
  it('identifies dual hazard when both gas and acoustic elevations occur', () => {
    const event: Event = {
      id: 1,
      device_id: 'RIG-001',
      session_id: 1,
      trainee_id: 'TR-101',
      event_kind: 'telemetry',
      device_timestamp: null,
      server_timestamp: new Date().toISOString(),
      device_uptime_ms: null,
      event_name: 'multi_hazard',
      alert: 'DANGER',
      cause: 'leak_detected',
      model_label: '(rms + gas)',
      leak_probability: 0.88,
      rms: 1850,
      gas_delta: 320,
      gas_ratio: 0.65,
      temperature: null,
      uv_delta: null,
      wet: null,
    };

    const insight = getExplainableInsight(event);
    expect(insight.severity).toBe('CRITICAL');
    expect(insight.headline).toContain('Dual Acoustic Elevation & Combustible Gas');
    expect(insight.safetyCaveat).toContain('MQ-2 readings are relative indications only');
  });

  it('includes negative diagnostic rule caveat for high acoustic leak', () => {
    const event: Event = {
      id: 2,
      device_id: 'RIG-002',
      session_id: 1,
      trainee_id: 'TR-102',
      event_kind: 'telemetry',
      device_timestamp: null,
      server_timestamp: new Date().toISOString(),
      device_uptime_ms: null,
      event_name: 'acoustic_leak',
      alert: 'DANGER',
      cause: 'high_rms',
      model_label: '(rms)',
      leak_probability: 0.92,
      rms: 2100,
      gas_delta: 0,
      gas_ratio: 1.0,
      temperature: null,
      uv_delta: null,
      wet: false,
    };

    const insight = getExplainableInsight(event);
    expect(insight.severity).toBe('CRITICAL');
    expect(insight.safetyCaveat).toContain('LOCAL surface vibrations only');
    expect(insight.safetyCaveat).toContain('Negative reading does NOT prove pipe is leak-free');
  });

  it('correctly labels baseline nominal operating state', () => {
    const event: Event = {
      id: 3,
      device_id: 'RIG-003',
      session_id: 1,
      trainee_id: 'TR-103',
      event_kind: 'telemetry',
      device_timestamp: null,
      server_timestamp: new Date().toISOString(),
      device_uptime_ms: null,
      event_name: 'normal',
      alert: 'NORMAL',
      cause: null,
      model_label: 'normal',
      leak_probability: 0.05,
      rms: 180,
      gas_delta: 12,
      gas_ratio: 0.98,
      temperature: null,
      uv_delta: null,
      wet: false,
    };

    const insight = getExplainableInsight(event);
    expect(insight.severity).toBe('NORMAL');
    expect(insight.headline).toBe('Normal Baseline Operating State');
  });
});
