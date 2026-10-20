import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { BRAND_PREFIX, BRAND_ACCENT, BRAND_SUBTITLE } from '../../constants/brand';

export const TrainerScreenPreview: React.FC = () => {
  const [timeUtc, setTimeUtc] = useState('14:38:14');
  const [isRefreshing, setIsRefreshing] = useState(false);

  useEffect(() => {
    const update = () => {
      const now = new Date();
      const hours = String(now.getUTCHours()).padStart(2, '0');
      const mins = String(now.getUTCMinutes()).padStart(2, '0');
      const secs = String(now.getUTCSeconds()).padStart(2, '0');
      setTimeUtc(`${hours}:${mins}:${secs}`);
    };
    update();
    const interval = setInterval(update, 1000);
    return () => clearInterval(interval);
  }, []);

  const handleRefresh = () => {
    setIsRefreshing(true);
    setTimeout(() => setIsRefreshing(false), 600);
  };

  return (
    <section className="s" id="dash">
      <div className="w">
        <div className="eyebrow">The trainer's screen</div>
        <h3 className="big">
          Lights up<br />after the scene
        </h3>
        <p className="sub">
          Direct inspection of the live HazGuard Command Centre Console. Live multi-modal telemetry, device fleet status, and NSQF Level 4 training aggregation.
        </p>

        {/* Authentic Command Centre Preview Window */}
        <div className="lit-window">
          {/* Console Body: Sidebar + Main Workspace */}
          <div className="lit-body">
            {/* Sidebar */}
            <aside className="lit-sidebar" aria-label="Console Navigation Preview">
              <div className="lit-sb-header">
                <div className="lit-sb-logo">
                  {BRAND_PREFIX}
                  <i>{BRAND_ACCENT[0]}</i>
                  {BRAND_ACCENT.slice(1)}
                </div>
                <div className="lit-sb-sub">{BRAND_SUBTITLE}</div>
              </div>

              <nav className="lit-sb-nav">
                <Link to="/dashboard" className="lit-nav-item active">
                  <svg className="lit-nav-icon" viewBox="0 0 16 16" fill="none">
                    <rect x="1" y="1" width="6" height="6" rx="1.5" fill="currentColor" opacity="0.9" />
                    <rect x="9" y="1" width="6" height="6" rx="1.5" fill="currentColor" opacity="0.9" />
                    <rect x="1" y="9" width="6" height="6" rx="1.5" fill="currentColor" opacity="0.9" />
                    <rect x="9" y="9" width="6" height="6" rx="1.5" fill="currentColor" opacity="0.9" />
                  </svg>
                  <span>Overview</span>
                </Link>

                <Link to="/diagnostics" className="lit-nav-item">
                  <svg className="lit-nav-icon" viewBox="0 0 16 16" fill="none">
                    <path d="M2 13h12M4 9l3-4 2.5 3 2.5-5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                    <circle cx="9.5" cy="8" r="1" fill="currentColor" />
                  </svg>
                  <span>Diagnostic Workspace</span>
                </Link>

                <Link to="/training" className="lit-nav-item">
                  <svg className="lit-nav-icon" viewBox="0 0 16 16" fill="none">
                    <path d="M8 2l6 3.5v5L8 14 2 10.5v-5L8 2z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" />
                    <path d="M8 6v4M6 8h4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                  </svg>
                  <span>Training Studio</span>
                </Link>

                <Link to="/devices" className="lit-nav-item">
                  <svg className="lit-nav-icon" viewBox="0 0 16 16" fill="none">
                    <rect x="1" y="3" width="10" height="8" rx="1.5" stroke="currentColor" strokeWidth="1.5" />
                    <path d="M13 6h1a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1h-1" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                    <path d="M4 11v2M8 11v2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                    <path d="M2 13h8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                  </svg>
                  <span>Devices</span>
                </Link>

                <Link to="/sessions" className="lit-nav-item">
                  <svg className="lit-nav-icon" viewBox="0 0 16 16" fill="none">
                    <rect x="1" y="2" width="14" height="12" rx="2" stroke="currentColor" strokeWidth="1.5" />
                    <path d="M1 6h14" stroke="currentColor" strokeWidth="1.5" />
                    <circle cx="5" cy="4" r="0.75" fill="currentColor" />
                    <circle cx="8" cy="4" r="0.75" fill="currentColor" />
                    <circle cx="11" cy="4" r="0.75" fill="currentColor" />
                    <path d="M4 9h3M4 11.5h5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                  </svg>
                  <span>Sessions</span>
                </Link>

                <Link to="/trainees" className="lit-nav-item">
                  <svg className="lit-nav-icon" viewBox="0 0 16 16" fill="none">
                    <circle cx="8" cy="5" r="3" stroke="currentColor" strokeWidth="1.5" />
                    <path d="M2 14c0-3.314 2.686-5 6-5s6 1.686 6 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                  </svg>
                  <span>Trainees</span>
                </Link>

                <Link to="/assessments" className="lit-nav-item">
                  <svg className="lit-nav-icon" viewBox="0 0 16 16" fill="none">
                    <rect x="2" y="1" width="12" height="14" rx="2" stroke="currentColor" strokeWidth="1.5" />
                    <path d="M5 5h6M5 8h6M5 11h4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                  </svg>
                  <span>Assessments</span>
                </Link>

                <Link to="/alerts" className="lit-nav-item">
                  <svg className="lit-nav-icon" viewBox="0 0 16 16" fill="none">
                    <path d="M8 1L1.5 13h13L8 1z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" />
                    <path d="M8 6v3.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                    <circle cx="8" cy="11.5" r="0.75" fill="currentColor" />
                  </svg>
                  <span>Alerts</span>
                </Link>
              </nav>

              <div className="lit-sb-footer">
                <div className="lit-sb-role">
                  <span className="lit-green-dot" />
                  <span>Role: Trainer / Assessor</span>
                </div>
                <Link to="/login" className="lit-sb-signout">
                  <svg width="13" height="13" viewBox="0 0 16 16" fill="none">
                    <path d="M6 2H3a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3M10 11l3-3-3-3M13 8H6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                  <span>Sign Out</span>
                </Link>
              </div>
            </aside>

            {/* Main Console Workspace */}
            <main className="lit-main">
              {/* Internal Topbar */}
              <div className="lit-topbar">
                <span className="lit-topbar-title">Command Centre Overview</span>

                <div className="lit-topbar-actions">
                  <span className="lit-badge" style={{ background: '#FFFFFF' }}>
                    <span className="lit-green-dot" />
                    Live Backend
                  </span>

                  <button
                    className="lit-badge"
                    style={{ background: '#FFFFFF', cursor: 'pointer', padding: '4px 8px' }}
                    title="Toggle console theme"
                    aria-label="Theme toggle"
                  >
                    <svg width="13" height="13" viewBox="0 0 16 16" fill="currentColor" style={{ opacity: 0.7 }}>
                      <path d="M6 .278a.768.768 0 0 1 .08.858 7.208 7.208 0 0 0-.878 3.46c0 4.021 3.278 7.277 7.318 7.277.527 0 1.04-.055 1.533-.16a.787.787 0 0 1 .81.316.733.733 0 0 1-.031.893A8.349 8.349 0 0 1 8.344 16C3.734 16 0 12.286 0 7.71 0 4.266 2.114 1.312 5.124.06A.752.752 0 0 1 6 .278z" />
                    </svg>
                  </button>

                  <span className="lit-badge" style={{ background: '#FFFFFF', color: '#252525' }}>
                    <span className="lit-green-dot" />
                    PS26244
                  </span>

                  <Link
                    to="/dashboard"
                    className="lit-badge"
                    style={{
                      background: 'var(--or)',
                      color: '#17100B',
                      borderColor: 'var(--or)',
                      textDecoration: 'none',
                      fontWeight: 700,
                      cursor: 'pointer',
                    }}
                  >
                    Enter Live Console →
                  </Link>
                </div>
              </div>

              {/* Console Dashboard Content */}
              <div className="lit-dash-view">
                {/* Header Title & Status Controls */}
                <div className="lit-overview-header">
                  <div>
                    <h4>Command Centre Overview</h4>
                    <p>Diagnostic sensing wearables, session telemetry &amp; NSQF vocational training aggregation</p>
                  </div>

                  <div className="lit-status-cluster">
                    <div className="lit-status-pill">
                      <span className="lit-green-dot" />
                      <span>
                        Backend <strong>Healthy</strong>
                      </span>
                      <span style={{ color: '#E9E5DE' }}>|</span>
                      <span>
                        DB <strong>connected</strong>
                      </span>
                    </div>

                    <div className="lit-time-pill">{timeUtc} UTC</div>
                    <span style={{ fontSize: 11.5, color: '#716D67' }}>Updated {timeUtc}</span>

                    <button
                      className="lit-refresh-btn"
                      onClick={handleRefresh}
                      title="Simulate data refresh"
                    >
                      <svg
                        width="12"
                        height="12"
                        viewBox="0 0 13 13"
                        fill="none"
                        style={{
                          transform: isRefreshing ? 'rotate(360deg)' : 'none',
                          transition: 'transform 0.6s ease',
                        }}
                      >
                        <path d="M11 2.5A5.5 5.5 0 1 0 12 7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
                        <path d="M9 0v3h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                      Refresh
                    </button>
                  </div>
                </div>

                {/* Quick Launch Action Ribbon (3 Cards) */}
                <div className="lit-action-grid">
                  <Link
                    to="/diagnostics"
                    className="lit-action-card"
                    style={{ borderLeft: '4px solid #F07842' }}
                  >
                    <div
                      className="lit-action-icon"
                      style={{ background: 'rgba(240, 120, 66, 0.12)', color: '#F07842' }}
                    >
                      🔍
                    </div>
                    <div>
                      <div className="lit-action-title">Diagnostic Workspace</div>
                      <div className="lit-action-desc">
                        Inspect live &amp; recorded multi-modal observations with explainable feedback
                      </div>
                    </div>
                  </Link>

                  <Link
                    to="/training"
                    className="lit-action-card"
                    style={{ borderLeft: '4px solid #35C27A' }}
                  >
                    <div
                      className="lit-action-icon"
                      style={{ background: 'rgba(53, 194, 122, 0.12)', color: '#35C27A' }}
                    >
                      🎓
                    </div>
                    <div>
                      <div className="lit-action-title">Vocational Training Studio</div>
                      <div className="lit-action-desc">
                        Launch guided leak diagnosis drills aligned to NSQF Level 4 trades
                      </div>
                    </div>
                  </Link>

                  <Link
                    to="/assessments"
                    className="lit-action-card"
                    style={{ borderLeft: '4px solid #F2A20C' }}
                  >
                    <div
                      className="lit-action-icon"
                      style={{ background: 'rgba(242, 162, 12, 0.12)', color: '#F2A20C' }}
                    >
                      📋
                    </div>
                    <div>
                      <div className="lit-action-title">NSQF Skill Assessments</div>
                      <div className="lit-action-desc">
                        Review candidate scores, rubric parameters, and authorized trainer overrides
                      </div>
                    </div>
                  </Link>
                </div>

                {/* 5 KPI Metric Cards */}
                <div className="lit-kpi-row">
                  {/* Registered Devices */}
                  <div className="lit-kpi-card" style={{ borderTop: '3px solid #F07842' }}>
                    <div className="lit-kpi-label">Registered Devices</div>
                    <div className="lit-kpi-value">0</div>
                    <div className="lit-kpi-badges">
                      <span className="lit-badge-pill lit-badge-ok">0 ONLINE</span>
                      <span className="lit-badge-pill lit-badge-neutral">0 OFFLINE</span>
                    </div>
                  </div>

                  {/* Training Sessions */}
                  <div className="lit-kpi-card" style={{ borderTop: '3px solid #A94E29' }}>
                    <div className="lit-kpi-label">Training Sessions</div>
                    <div className="lit-kpi-value">0</div>
                    <div className="lit-kpi-meta">
                      <strong>0</strong> in last 24 hours
                    </div>
                  </div>

                  {/* Enrolled Trainees */}
                  <div className="lit-kpi-card" style={{ borderTop: '3px solid #D8C9BA' }}>
                    <div className="lit-kpi-label">Enrolled Trainees</div>
                    <div className="lit-kpi-value">0</div>
                    <div className="lit-kpi-meta">Vocational candidates across active cohorts</div>
                  </div>

                  {/* Hazard Alerts */}
                  <div className="lit-kpi-card" style={{ borderTop: '3px solid #EE4B3E' }}>
                    <div className="lit-kpi-label">Hazard Alerts</div>
                    <div className="lit-kpi-value">0</div>
                    <div className="lit-kpi-meta">Recorded DANGER / CAUTION threshold events</div>
                  </div>

                  {/* Ingested Observations */}
                  <div className="lit-kpi-card" style={{ borderTop: '3px solid #E9E5DE' }}>
                    <div className="lit-kpi-label">Ingested Observations</div>
                    <div className="lit-kpi-value">0</div>
                    <div className="lit-kpi-meta">Multi-modal sensor telemetry records</div>
                  </div>
                </div>

                {/* Bottom 2-Column Industrial Grid */}
                <div className="lit-bottom-grid">
                  {/* Hardware Fleet Sensor Matrix */}
                  <div className="lit-panel">
                    <div className="lit-panel-header">
                      <h5 className="lit-panel-title">Hardware Fleet Sensor Matrix (Firmware 1.1.0)</h5>
                      <span className="lit-panel-tag">ESP32-S3 / Xtensa</span>
                    </div>
                    <p className="lit-panel-desc">
                      Declared hardware state, calibration basis, and empirical validation transparency.
                    </p>

                    <div className="lit-panel-list">
                      <div className="lit-list-item">
                        <div className="lit-item-top">
                          <strong>Contact Acoustic Piezo</strong>
                          <span className="lit-status-tag active">ACTIVE</span>
                        </div>
                        <div className="lit-item-sub">
                          12-bit ADC @ 8kHz (RMS fallback). Localized vibration only; no spatial triangulation.
                        </div>
                      </div>

                      <div className="lit-list-item">
                        <div className="lit-item-top">
                          <strong>MQ-2 Combustible Gas</strong>
                          <span className="lit-status-tag indicative">INDICATIVE</span>
                        </div>
                        <div className="lit-item-sub">
                          Relative ADC delta / Rs/R0 ratio. Indicative only; not certified ppm or %LEL.
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Vocational NSQF Trade Alignment */}
                  <div className="lit-panel">
                    <div className="lit-panel-header">
                      <h5 className="lit-panel-title">Vocational NSQF Trade Alignment (NQR Oct 2026)</h5>
                      <span className="lit-panel-tag orange">NQR VALIDATED</span>
                    </div>
                    <p className="lit-panel-desc">
                      Competency framework aligned to National Qualifications Register official occupational standards.
                    </p>

                    <div className="lit-panel-list">
                      <div className="lit-list-item">
                        <div className="lit-item-top">
                          <strong>Plumber (General)</strong>
                          <span className="lit-code-pill">PSC/Q0104 · Level 4</span>
                        </div>
                        <div className="lit-item-sub" style={{ color: '#716D67' }}>
                          Sector Skill Council: Water Management &amp; Plumbing Skill Council (WMPSC)
                        </div>
                        <div className="lit-item-sub" style={{ color: '#252525', fontWeight: 500 }}>
                          Diagnostic Scope: Pressurized joint acoustic inspection, multi-point leak comparative screening.
                        </div>
                      </div>

                      <div className="lit-list-item">
                        <div className="lit-item-top">
                          <strong>Field Technician — AC</strong>
                          <span className="lit-code-pill">ELE/Q3102 · Level 4</span>
                        </div>
                        <div className="lit-item-sub" style={{ color: '#716D67' }}>
                          Sector Skill Council: Electronics Sector Skills Council of India (ESSCI)
                        </div>
                        <div className="lit-item-sub" style={{ color: '#252525', fontWeight: 500 }}>
                          Diagnostic Scope: Refrigerant line screening, brazed joint acoustic verification, compressor line audit.
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </main>
          </div>
        </div>
      </div>
    </section>
  );
};

export default TrainerScreenPreview;
