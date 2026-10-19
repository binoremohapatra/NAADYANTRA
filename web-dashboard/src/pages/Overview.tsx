import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { apiClient } from '../api/client';
import { useDemo } from '../context/DemoContext';
import type { DashboardOverview } from '../types';

export default function Overview() {
  const { isDemoMode, demoData } = useDemo();

  const [overview, setOverview] = useState<DashboardOverview | null>(null);
  const [activeAlertsCount, setActiveAlertsCount] = useState<number>(0);
  const [apiStatus, setApiStatus] = useState<'healthy' | 'disconnected' | 'unknown'>('unknown');
  const [dbStatus, setDbStatus] = useState<string>('unknown');
  const [serverUtc, setServerUtc] = useState<string>('');
  const [lastRefresh, setLastRefresh] = useState<Date | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');

  const loadOverview = useCallback(async () => {
    try {
      setError('');

      if (isDemoMode) {
        setApiStatus('healthy');
        setDbStatus('connected (simulated)');
        setOverview(demoData.overview);
        setActiveAlertsCount(demoData.overview.alert_events_count || 14);
        setServerUtc(new Date().toLocaleTimeString());
        setLastRefresh(new Date());
        setIsLoading(false);
        return;
      }

      try {
        const ready = await apiClient.readyCheck();
        setApiStatus('healthy');
        setDbStatus(ready.database || 'connected');
      } catch {
        setApiStatus('disconnected');
        setDbStatus('error');
      }

      const data = await apiClient.getDashboardOverview();
      setOverview(data);
      if (data.server_utc) {
        setServerUtc(new Date(data.server_utc).toLocaleTimeString());
      }

      const alertsCount = await apiClient.getRecordedAlertsCount();
      setActiveAlertsCount(alertsCount);

      setLastRefresh(new Date());
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load operational overview');
    } finally {
      setIsLoading(false);
    }
  }, [isDemoMode, demoData.overview]);

  useEffect(() => {
    loadOverview();
    const interval = setInterval(loadOverview, 15000);
    return () => clearInterval(interval);
  }, [loadOverview]);

  if (isLoading) {
    return (
      <div className="hg-loading-screen">
        <div className="hg-spinner" />
        <span style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>
          Loading operational overview…
        </span>
      </div>
    );
  }

  if (error && !overview) {
    return (
      <div className="hg-alert hg-alert-error" style={{ maxWidth: 480 }}>
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ flexShrink: 0 }}>
          <circle cx="8" cy="8" r="7" stroke="currentColor" strokeWidth="1.5" />
          <path d="M8 5v3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
          <circle cx="8" cy="11" r="0.75" fill="currentColor" />
        </svg>
        {error}
      </div>
    );
  }

  const onlineCount = overview?.online_devices_count ?? overview?.active_devices_count ?? 0;
  const offlineCount =
    overview?.offline_devices_count ??
    ((overview?.total_devices ?? 0) - (overview?.active_devices_count ?? 0));

  return (
    <div>
      {/* Page header */}
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">Command Centre Overview</h1>
          <p className="hg-page-subtitle">
            Diagnostic sensing wearables, session telemetry &amp; NSQF vocational training aggregation
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
          {/* Status pills */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              background: 'var(--color-white)',
              border: '1px solid var(--color-warm-stone)',
              borderRadius: 99,
              padding: '6px 14px',
              fontSize: 12,
            }}
          >
            <span className={`hg-dot ${apiStatus === 'healthy' ? 'hg-dot-ok hg-dot-pulse' : 'hg-dot-danger'}`} />
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              Backend&nbsp;
              <strong style={{ color: 'var(--color-carbon)' }}>
                {apiStatus === 'healthy' ? (isDemoMode ? 'Simulated' : 'Healthy') : 'Offline'}
              </strong>
            </span>
            <span style={{ color: 'var(--color-warm-stone)' }}>|</span>
            <span style={{ color: 'var(--color-warm-graphite)' }}>
              DB&nbsp;<strong style={{ color: 'var(--color-carbon)' }}>{dbStatus}</strong>
            </span>
          </div>

          {serverUtc && (
            <span
              style={{
                fontFamily: 'var(--font-mono)',
                fontSize: 11,
                color: 'var(--color-warm-graphite)',
                background: 'var(--color-white)',
                border: '1px solid var(--color-warm-stone)',
                borderRadius: 6,
                padding: '5px 10px',
              }}
            >
              {serverUtc} UTC
            </span>
          )}

          {lastRefresh && (
            <span style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
              Updated {lastRefresh.toLocaleTimeString()}
            </span>
          )}

          <button className="hg-btn hg-btn-secondary" onClick={loadOverview}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
              <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            Refresh
          </button>
        </div>
      </div>

      {/* Quick Launch Action Ribbon */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
          gap: 14,
          marginBottom: 24,
        }}
      >
        <Link
          to="/diagnostics"
          className="hg-card"
          style={{
            textDecoration: 'none',
            display: 'flex',
            alignItems: 'center',
            gap: 14,
            borderLeft: '4px solid var(--color-burnt-orange)',
            transition: 'transform var(--transition-fast), box-shadow var(--transition-fast)',
          }}
        >
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: 8,
              background: 'rgba(240, 120, 66, 0.12)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 20,
              flexShrink: 0,
            }}
          >
            🔍
          </div>
          <div>
            <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-carbon)' }}>Diagnostic Workspace</div>
            <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', marginTop: 2 }}>
              Inspect live &amp; recorded multi-modal observations with explainable feedback
            </div>
          </div>
        </Link>

        <Link
          to="/training"
          className="hg-card"
          style={{
            textDecoration: 'none',
            display: 'flex',
            alignItems: 'center',
            gap: 14,
            borderLeft: '4px solid #4CAF50',
            transition: 'transform var(--transition-fast), box-shadow var(--transition-fast)',
          }}
        >
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: 8,
              background: 'rgba(76, 175, 80, 0.12)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 20,
              flexShrink: 0,
            }}
          >
            🎓
          </div>
          <div>
            <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-carbon)' }}>Vocational Training Studio</div>
            <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', marginTop: 2 }}>
              Launch guided leak diagnosis drills aligned to NSQF Level 4 trades
            </div>
          </div>
        </Link>

        <Link
          to="/assessments"
          className="hg-card"
          style={{
            textDecoration: 'none',
            display: 'flex',
            alignItems: 'center',
            gap: 14,
            borderLeft: '4px solid #FF9800',
            transition: 'transform var(--transition-fast), box-shadow var(--transition-fast)',
          }}
        >
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: 8,
              background: 'rgba(255, 152, 0, 0.12)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 20,
              flexShrink: 0,
            }}
          >
            📋
          </div>
          <div>
            <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-carbon)' }}>NSQF Skill Assessments</div>
            <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', marginTop: 2 }}>
              Review candidate scores, rubric parameters, and authorized trainer overrides
            </div>
          </div>
        </Link>

        <Link
          to="/feed"
          className="hg-card"
          style={{
            textDecoration: 'none',
            display: 'flex',
            alignItems: 'center',
            gap: 14,
            borderLeft: '4px solid var(--color-burnt-orange)',
            transition: 'transform var(--transition-fast), box-shadow var(--transition-fast)',
          }}
        >
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: 8,
              background: 'rgba(240, 120, 66, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 20,
              flexShrink: 0,
            }}
          >
            📡
          </div>
          <div>
            <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-carbon)' }}>Live Telemetry Feed</div>
            <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', marginTop: 2 }}>
              Continuous multi-device event stream with real-time polling cadence controls
            </div>
          </div>
        </Link>

        <Link
          to="/bom"
          className="hg-card"
          style={{
            textDecoration: 'none',
            display: 'flex',
            alignItems: 'center',
            gap: 14,
            borderLeft: '4px solid var(--color-dark-orange)',
            transition: 'transform var(--transition-fast), box-shadow var(--transition-fast)',
          }}
        >
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: 8,
              background: 'rgba(169, 78, 41, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 20,
              flexShrink: 0,
            }}
          >
            ⚙️
          </div>
          <div>
            <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-carbon)' }}>Hardware BOM &amp; Cost</div>
            <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)', marginTop: 2 }}>
              Itemized low-cost prototype BOM ($&lt; $35 USD) &amp; engineering sourcing rationales
            </div>
          </div>
        </Link>
      </div>

      {/* Metric Cards */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))',
          gap: 16,
          marginBottom: 24,
        }}
      >
        {/* Devices */}
        <div className="hg-card" style={{ borderTop: '3px solid var(--color-burnt-orange)' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--color-warm-graphite)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Registered Devices
          </div>
          <div style={{ fontSize: 32, fontWeight: 800, color: 'var(--color-carbon)', margin: '8px 0 4px', fontFamily: 'var(--font-mono)' }}>
            {overview?.total_devices ?? 0}
          </div>
          <div style={{ display: 'flex', gap: 6, alignItems: 'center', fontSize: 12 }}>
            <span className="hg-badge hg-badge-ok">{onlineCount} online</span>
            <span className="hg-badge hg-badge-neutral">{offlineCount} offline</span>
          </div>
        </div>

        {/* Sessions */}
        <div className="hg-card" style={{ borderTop: '3px solid var(--color-dark-burnt-orange)' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--color-warm-graphite)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Training Sessions
          </div>
          <div style={{ fontSize: 32, fontWeight: 800, color: 'var(--color-carbon)', margin: '8px 0 4px', fontFamily: 'var(--font-mono)' }}>
            {overview?.total_sessions ?? 0}
          </div>
          <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
            <strong>{overview?.recent_sessions_count ?? 0}</strong> in last 24 hours
          </div>
        </div>

        {/* Trainees */}
        <div className="hg-card" style={{ borderTop: '3px solid var(--color-soft-sand)' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--color-warm-graphite)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Enrolled Trainees
          </div>
          <div style={{ fontSize: 32, fontWeight: 800, color: 'var(--color-carbon)', margin: '8px 0 4px', fontFamily: 'var(--font-mono)' }}>
            {overview?.total_trainees ?? 0}
          </div>
          <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
            Vocational candidates across active cohorts
          </div>
        </div>

        {/* Alerts */}
        <div className="hg-card" style={{ borderTop: '3px solid var(--color-alert-danger)' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--color-warm-graphite)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Hazard Alerts
          </div>
          <div
            style={{
              fontSize: 32,
              fontWeight: 800,
              color: activeAlertsCount > 0 ? 'var(--color-alert-danger)' : 'var(--color-carbon)',
              margin: '8px 0 4px',
              fontFamily: 'var(--font-mono)',
            }}
          >
            {activeAlertsCount}
          </div>
          <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
            Recorded DANGER / CAUTION threshold events
          </div>
        </div>

        {/* Total Events */}
        <div className="hg-card" style={{ borderTop: '3px solid var(--color-warm-stone)' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--color-warm-graphite)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Ingested Observations
          </div>
          <div style={{ fontSize: 32, fontWeight: 800, color: 'var(--color-carbon)', margin: '8px 0 4px', fontFamily: 'var(--font-mono)' }}>
            {overview?.total_events ?? 0}
          </div>
          <div style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>
            Multi-modal sensor telemetry records
          </div>
        </div>
      </div>

      {/* Two-Column Industrial Grid: Hardware Sensor Matrix & NSQF Alignment */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(440px, 1fr))', gap: 20 }}>
        {/* Hardware Modality & Transparency Matrix */}
        <div className="hg-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <h2 style={{ fontSize: 15, margin: 0, color: 'var(--color-carbon)' }}>
              Hardware Fleet Sensor Matrix (Firmware 1.1.0)
            </h2>
            <span className="hg-code" style={{ fontSize: 11 }}>ESP32-S3 / Xtensa</span>
          </div>
          <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', margin: '0 0 16px' }}>
            Declared hardware state, calibration basis, and empirical validation transparency.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {/* Contact Piezo */}
            <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px solid var(--color-warm-stone)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <strong style={{ fontSize: 12, color: 'var(--color-carbon)' }}>Contact Acoustic Piezo</strong>
                <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)' }}>
                  12-bit ADC @ 8kHz (RMS fallback). Localized vibration only; no spatial triangulation.
                </div>
              </div>
              <span className="hg-state-badge hg-state-normal">ACTIVE</span>
            </div>

            {/* MQ-2 Gas */}
            <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px solid var(--color-warm-stone)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <strong style={{ fontSize: 12, color: 'var(--color-carbon)' }}>MQ-2 Combustible Gas</strong>
                <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)' }}>
                  Relative ADC delta / Rs/R0 ratio. Indicative only; not certified ppm or %LEL.
                </div>
              </div>
              <span className="hg-state-badge hg-state-warning">INDICATIVE</span>
            </div>

            {/* Moisture Probe */}
            <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px solid var(--color-warm-stone)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <strong style={{ fontSize: 12, color: 'var(--color-carbon)' }}>Moisture Conduction Probe</strong>
                <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)' }}>
                  Interleaved pulsed excitation on PIN_MOIST_PWR to prevent galvanic corrosion.
                </div>
              </div>
              <span className="hg-state-badge hg-state-normal">ACTIVE</span>
            </div>

            {/* MLX90614 Contactless IR */}
            <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px dashed var(--color-warm-stone)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <strong style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>MLX90614 Contactless Pyrometer</strong>
                <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)' }}>
                  Disabled in firmware build (HAS_HEAT_SENSOR 0). Unverified hardware.
                </div>
              </div>
              <span className="hg-state-badge hg-state-disabled">DISABLED IN FW</span>
            </div>

            {/* GUVA-S12SD UV */}
            <div style={{ background: 'var(--color-ivory)', padding: 10, borderRadius: 6, border: '1px dashed var(--color-warm-stone)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <strong style={{ fontSize: 12, color: 'var(--color-warm-graphite)' }}>GUVA-S12SD UV Radiometer</strong>
                <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)' }}>
                  Disabled in firmware build (HAS_UV_SENSOR 0). Welding arc sensor unverified.
                </div>
              </div>
              <span className="hg-state-badge hg-state-disabled">DISABLED IN FW</span>
            </div>
          </div>
        </div>

        {/* NSQF Vocational Curriculum Alignment */}
        <div className="hg-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <h2 style={{ fontSize: 15, margin: 0, color: 'var(--color-carbon)' }}>
              Vocational NSQF Trade Alignment (NQR Oct 2026)
            </h2>
            <span className="hg-badge hg-badge-orange">NQR Validated</span>
          </div>
          <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', margin: '0 0 16px' }}>
            Competency framework aligned to National Qualifications Register official occupational standards.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {/* Plumber */}
            <div style={{ background: 'var(--color-ivory)', padding: 12, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <strong style={{ fontSize: 13, color: 'var(--color-carbon)' }}>Plumber (General)</strong>
                <span className="hg-code">PSC/Q0104 · Level 4</span>
              </div>
              <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
                Sector Skill Council: Water Management &amp; Plumbing Skill Council (WMPSC)
              </div>
              <div style={{ fontSize: 11, color: 'var(--color-carbon)', marginTop: 4 }}>
                Diagnostic Scope: Pressurized joint acoustic inspection, multi-point leak comparative screening.
              </div>
            </div>

            {/* AC Technician */}
            <div style={{ background: 'var(--color-ivory)', padding: 12, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <strong style={{ fontSize: 13, color: 'var(--color-carbon)' }}>Field Technician — AC</strong>
                <span className="hg-code">ELE/Q3102 · Level 4</span>
              </div>
              <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
                Sector Skill Council: Electronics Sector Skills Council of India (ESSCI)
              </div>
              <div style={{ fontSize: 11, color: 'var(--color-carbon)', marginTop: 4 }}>
                Diagnostic Scope: Refrigerant line screening, brazed joint acoustic verification, compressor line audit.
              </div>
            </div>

            {/* Mechanical Fitter */}
            <div style={{ background: 'var(--color-ivory)', padding: 12, borderRadius: 6, border: '1px solid var(--color-warm-stone)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <strong style={{ fontSize: 13, color: 'var(--color-carbon)' }}>Fitter — Mechanical Assembly</strong>
                <span className="hg-code">CSC/Q0901 · Level 3</span>
              </div>
              <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
                Sector Skill Council: Capital Goods Skill Council (CGSC)
              </div>
              <div style={{ fontSize: 11, color: 'var(--color-carbon)', marginTop: 4 }}>
                Diagnostic Scope: Assembly inspection of fluid fittings, hydraulic/pneumatic valves, mechanical sealing.
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
