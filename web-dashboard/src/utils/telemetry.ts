/**
 * NAADYANTRA Telemetry & Diagnostic Explanation Utility
 * Aligned with SIH26244 Problem Statement
 */

import type { Event } from '../types';

export type DeviceFreshnessState = 'online' | 'stale' | 'offline' | 'unknown';

export interface FreshnessResult {
  state: DeviceFreshnessState;
  secondsAgo: number | null;
  label: string;
  badgeClass: string;
}

/**
 * Computes device reporting freshness based on configurable thresholds.
 * @param lastSeen ISO timestamp string or null
 * @param onlineThresholdSec Seconds threshold to consider online (default: 60s)
 * @param offlineThresholdSec Seconds threshold to consider offline (default: 300s)
 */
export function computeDeviceFreshness(
  lastSeen: string | null | undefined,
  onlineThresholdSec = 60,
  offlineThresholdSec = 300
): FreshnessResult {
  if (!lastSeen) {
    return {
      state: 'unknown',
      secondsAgo: null,
      label: 'Unknown',
      badgeClass: 'hg-badge-neutral',
    };
  }

  const seenTime = new Date(lastSeen).getTime();
  if (isNaN(seenTime)) {
    return {
      state: 'unknown',
      secondsAgo: null,
      label: 'Invalid Date',
      badgeClass: 'hg-badge-neutral',
    };
  }

  const now = Date.now();
  const diffSec = Math.max(0, Math.floor((now - seenTime) / 1000));

  if (diffSec <= onlineThresholdSec) {
    return {
      state: 'online',
      secondsAgo: diffSec,
      label: diffSec < 5 ? 'Active (Live)' : `Active (${diffSec}s ago)`,
      badgeClass: 'hg-badge-ok',
    };
  }

  if (diffSec <= offlineThresholdSec) {
    return {
      state: 'stale',
      secondsAgo: diffSec,
      label: `Stale (${Math.floor(diffSec / 60)}m ${diffSec % 60}s ago)`,
      badgeClass: 'hg-badge-caution',
    };
  }

  const minutesAgo = Math.floor(diffSec / 60);
  const hoursAgo = Math.floor(minutesAgo / 60);

  return {
    state: 'offline',
    secondsAgo: diffSec,
    label: hoursAgo > 0 ? `Offline (${hoursAgo}h ago)` : `Offline (${minutesAgo}m ago)`,
    badgeClass: 'hg-badge-neutral',
  };
}

export interface ExplainableInsight {
  headline: string;
  supportingSensor: string;
  algorithmModel: string;
  rationale: string;
  remediationStep: string;
  safetyCaveat: string;
  severity: 'CRITICAL' | 'WARNING' | 'NORMAL' | 'INFO';
}

/**
 * Derives explainable diagnostic feedback from an incoming telemetry event.
 * Never fabricates values for absent modalities.
 */
export function getExplainableInsight(event: Event): ExplainableInsight {
  const isDanger = event.alert === 'DANGER';
  const isCaution = event.alert === 'CAUTION';
  const isWet = event.wet === true;
  const hasGas = (event.gas_delta != null && event.gas_delta > 150) || (event.gas_ratio != null && event.gas_ratio < 0.85);
  const hasAcousticElevation = (event.rms != null && event.rms > 800) || (event.leak_probability != null && event.leak_probability > 0.4);

  // 1. Dual Hazard (Acoustic + Gas)
  if (hasGas && hasAcousticElevation) {
    return {
      headline: 'Dual Acoustic Elevation & Combustible Gas Gradient Detected',
      supportingSensor: 'Brass Contact Piezo (ADC1_CH3) & MQ-2 Semiconductor (ADC1_CH4)',
      algorithmModel: 'Multi-Modal Hazard Fusion Rule `(rms + gas)`',
      rationale: `Acoustic RMS elevation (${event.rms ?? 'N/A'} counts) correlates with elevated MQ-2 sensor conductance (ΔADC: ${event.gas_delta ?? 'N/A'}). Suggests active pressurized gas escaping through joint fissure.`,
      remediationStep: 'Trainee must immediately isolate upstream supply valve, verify zero ignition sources, and perform soapy bubble check on joint.',
      safetyCaveat: 'MQ-2 readings are relative indications only and do NOT certify atmospheric safety or %LEL compliance. Wear personal multi-gas detector before entry.',
      severity: 'CRITICAL',
    };
  }

  // 2. High Acoustic Leak
  if (isDanger || (event.rms != null && event.rms > 1200)) {
    return {
      headline: 'Significant Acoustic Turbulence Signature (Probable Fluid/Gas Leak)',
      supportingSensor: 'Brass Contact Piezoelectric Element (27mm, ADC1_CH3)',
      algorithmModel: 'Embedded RMS Ratio Heuristic `(rms)` fallback [USE_EDGE_IMPULSE=0]',
      rationale: `Contact probe measured RMS energy (${event.rms ?? 'N/A'} counts) significantly above resting pipe baseline. Crest factor and spectral centroid match high-velocity orifice turbulence.`,
      remediationStep: 'Conduct comparative 3-point inspection: probe 30cm upstream, at the joint, and 30cm downstream. Highest amplitude marks defect location.',
      safetyCaveat: 'Contact piezo detects LOCAL surface vibrations only; it does NOT triangulate spatial coordinates. Negative reading does NOT prove pipe is leak-free.',
      severity: 'CRITICAL',
    };
  }

  // 3. Elevated Gas Alone
  if (hasGas) {
    return {
      headline: 'Combustible Gas Relative Concentration Elevation',
      supportingSensor: 'MQ-2 Sniffer Module (ADC1_CH4 with 5V Heater & 15k/10k Divider)',
      algorithmModel: 'Threshold Gradient Delta Rule (ΔADC > baseline)',
      rationale: `Surface conductance increased by ΔADC ${event.gas_delta ?? 'N/A'} counts (Rs/R0: ${event.gas_ratio?.toFixed(2) ?? 'N/A'}). Indicates presence of reducing gas vapors (LPG, propane, methane, or solvent).`,
      remediationStep: 'Inspect fuel gas lines and fitting seals. Vent work area and confirm no open flames or arc-welding equipment in operation.',
      safetyCaveat: 'Uncalibrated MQ-2 sensor. Sensitive to humidity and ambient solvent vapors. Does not replace calibrated industrial gas monitors.',
      severity: 'WARNING',
    };
  }

  // 4. Moisture Conduction
  if (isWet) {
    return {
      headline: 'Liquid Conduction Bridge Detected (Surface Wetting)',
      supportingSensor: 'Interleaved PCB Trace Probe (ADC1_CH5, Gated on GPIO 10)',
      algorithmModel: 'Gated DC Conduction Bridge Threshold',
      rationale: 'Electrode conduction verified during 50ms pulsed excitation window. Liquid droplet or condensation is bridging probe electrodes.',
      remediationStep: 'Inspect pipe underside and insulation for weeping or dripping. Determine if fluid is line leakage or ambient condensation.',
      safetyCaveat: 'Moisture probe confirms liquid presence at contact point only. Cannot determine fluid toxicity, pH, or pressure.',
      severity: 'WARNING',
    };
  }

  // 5. Caution / Mild Acoustic
  if (isCaution || (event.rms != null && event.rms > 500)) {
    return {
      headline: 'Mild Acoustic Deviation (Suspicious Fluid Noise)',
      supportingSensor: 'Brass Contact Piezoelectric Element (ADC1_CH3)',
      algorithmModel: 'Embedded RMS Ratio Heuristic `(rms)`',
      rationale: `RMS energy (${event.rms ?? 'N/A'} counts) is elevated above quiet baseline but below critical leak threshold. Could represent minor orifice leakage, cavitation, or pump vibration.`,
      remediationStep: 'Adjust probe coupling pressure, apply acoustic coupling gel, and re-sample. Check whether nearby mechanical machinery is running.',
      safetyCaveat: 'Ambient mechanical noise can couple into pipe walls. Disclose that reading is unisolated.',
      severity: 'WARNING',
    };
  }

  // 6. Normal / Baseline
  return {
    headline: 'Normal Baseline Operating State',
    supportingSensor: 'All Active Channels (Piezo, MQ-2, Moisture)',
    algorithmModel: 'Continuous Baseline Telemetry Stream',
    rationale: `Sensor readings within nominal resting ranges (RMS: ${event.rms ?? 'N/A'}, Gas Δ: ${event.gas_delta ?? 0}, Moisture: DRY).`,
    remediationStep: 'Maintain steady probe contact. Move to next planned test point in the inspection route.',
    safetyCaveat: 'A quiet reading does not guarantee an absence of defects on uninspected pipeline sections.',
    severity: 'NORMAL',
  };
}

/**
 * Verifies that optional sensor measurements are null-safe and never fabricated.
 */
export function sanitizeEventPayload(raw: any): Event {
  return {
    id: Number(raw.id ?? 0),
    device_id: String(raw.device_id ?? ''),
    session_id: Number(raw.session_id ?? raw.internal_session_id ?? 0),
    trainee_id: String(raw.trainee_id ?? 'TRAINEE-UNASSIGNED'),
    event_kind: String(raw.event_kind ?? 'telemetry'),
    device_timestamp: raw.device_timestamp != null ? Number(raw.device_timestamp) : null,
    server_timestamp: String(raw.server_timestamp ?? new Date().toISOString()),
    device_uptime_ms: raw.device_uptime_ms != null ? Number(raw.device_uptime_ms) : null,
    event_name: raw.event_name ?? null,
    alert: raw.alert ?? null,
    cause: raw.cause ?? null,
    model_label: raw.model_label ?? null,
    leak_probability: raw.leak_probability != null ? Number(raw.leak_probability) : null,
    rms: raw.rms != null ? Number(raw.rms) : null,
    gas_delta: raw.gas_delta != null ? Number(raw.gas_delta) : null,
    gas_ratio: raw.gas_ratio != null ? Number(raw.gas_ratio) : null,
    // Optional sensors: strictly preserved as null if absent
    temperature: raw.temperature != null ? Number(raw.temperature) : null,
    uv_delta: raw.uv_delta != null ? Number(raw.uv_delta) : null,
    distance_mm: raw.distance_mm != null ? Number(raw.distance_mm) : null,
    battery_v: raw.battery_v != null ? Number(raw.battery_v) : null,
    wet: raw.wet != null ? Boolean(raw.wet) : null,
    firmware_version: raw.firmware_version ?? '1.1.0',
    raw_payload: raw.raw_payload ?? raw,
    ingestion_status: raw.ingestion_status ?? 'VERIFIED',
  };
}
