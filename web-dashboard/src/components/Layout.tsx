import { Outlet, NavLink, useNavigate, useLocation } from 'react-router-dom';
import { useState } from 'react';
import { apiClient } from '../api/client';
import { useTheme } from '../context/ThemeContext';
import { useDemo } from '../context/DemoContext';
import { useLanguage } from '../context/LanguageContext';

interface LayoutProps {
  onLogout: () => void;
}

const NAV_ITEMS = [
  {
    to: '/',
    key: 'nav.overview',
    label: 'Overview',
    exact: true,
    icon: (
      <svg className="hg-nav-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="1" y="1" width="6" height="6" rx="1.5" fill="currentColor" opacity="0.9"/>
        <rect x="9" y="1" width="6" height="6" rx="1.5" fill="currentColor" opacity="0.9"/>
        <rect x="1" y="9" width="6" height="6" rx="1.5" fill="currentColor" opacity="0.9"/>
        <rect x="9" y="9" width="6" height="6" rx="1.5" fill="currentColor" opacity="0.9"/>
      </svg>
    ),
  },
  {
    to: '/feed',
    key: 'nav.feed',
    label: 'Live Telemetry Feed',
    icon: (
      <svg className="hg-nav-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <circle cx="8" cy="8" r="2.5" fill="currentColor"/>
        <path d="M4.5 4.5a5 5 0 0 0 0 7M11.5 4.5a5 5 0 0 1 0 7" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
        <path d="M2.5 2.5a8 8 0 0 0 0 11M13.5 2.5a8 8 0 0 1 0 11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
      </svg>
    ),
  },
  {
    to: '/diagnostics',
    key: 'nav.diagnostics',
    label: 'Diagnostic Workspace',
    icon: (
      <svg className="hg-nav-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M2 13h12M4 9l3-4 2.5 3 2.5-5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
        <circle cx="9.5" cy="8" r="1" fill="currentColor"/>
      </svg>
    ),
  },
  {
    to: '/training',
    key: 'nav.training',
    label: 'Training Studio',
    icon: (
      <svg className="hg-nav-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M8 2l6 3.5v5L8 14 2 10.5v-5L8 2z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
        <path d="M8 6v4M6 8h4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
      </svg>
    ),
  },
  {
    to: '/devices',
    key: 'nav.devices',
    label: 'Devices',
    icon: (
      <svg className="hg-nav-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="1" y="3" width="10" height="8" rx="1.5" stroke="currentColor" strokeWidth="1.5"/>
        <path d="M13 6h1a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1h-1" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
        <path d="M4 11v2M8 11v2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
        <path d="M2 13h8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
      </svg>
    ),
  },
  {
    to: '/sessions',
    key: 'nav.sessions',
    label: 'Sessions',
    icon: (
      <svg className="hg-nav-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="1" y="2" width="14" height="12" rx="2" stroke="currentColor" strokeWidth="1.5"/>
        <path d="M1 6h14" stroke="currentColor" strokeWidth="1.5"/>
        <circle cx="5" cy="4" r="0.75" fill="currentColor"/>
        <circle cx="8" cy="4" r="0.75" fill="currentColor"/>
        <circle cx="11" cy="4" r="0.75" fill="currentColor"/>
        <path d="M4 9h3M4 11.5h5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
      </svg>
    ),
  },
  {
    to: '/trainees',
    key: 'nav.trainees',
    label: 'Trainees',
    icon: (
      <svg className="hg-nav-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <circle cx="8" cy="5" r="3" stroke="currentColor" strokeWidth="1.5"/>
        <path d="M2 14c0-3.314 2.686-5 6-5s6 1.686 6 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
      </svg>
    ),
  },
  {
    to: '/assessments',
    key: 'nav.assessments',
    label: 'Assessments',
    icon: (
      <svg className="hg-nav-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="2" y="1" width="12" height="14" rx="2" stroke="currentColor" strokeWidth="1.5"/>
        <path d="M5 5h6M5 8h6M5 11h4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
      </svg>
    ),
  },
  {
    to: '/alerts',
    key: 'nav.alerts',
    label: 'Alerts',
    icon: (
      <svg className="hg-nav-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M8 1L1.5 13h13L8 1z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
        <path d="M8 6v3.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
        <circle cx="8" cy="11.5" r="0.75" fill="currentColor"/>
      </svg>
    ),
  },
  {
    to: '/bom',
    key: 'nav.bom',
    label: 'Hardware BOM',
    icon: (
      <svg className="hg-nav-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="2" y="2" width="12" height="12" rx="2" stroke="currentColor" strokeWidth="1.5"/>
        <path d="M5 5h6M5 8h6M5 11h3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
      </svg>
    ),
  },
];

function Layout({ onLogout }: LayoutProps) {
  const navigate = useNavigate();
  const location = useLocation();
  const { theme, toggleTheme } = useTheme();
  const { isDemoMode, toggleDemoMode } = useDemo();
  const { lang, toggleLang, t } = useLanguage();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const handleLogout = async () => {
    try {
      await apiClient.logout();
    } catch {
      // ignore
    } finally {
      localStorage.removeItem('auth_token');
      onLogout();
      navigate('/login');
    }
  };

  // Determine current page title for the topbar
  const pageTitle = (() => {
    const path = location.pathname;
    if (path === '/') return t('title.overview', 'Command Centre Overview');
    if (path.startsWith('/feed')) return t('title.feed', 'Real-Time Combined Telemetry Feed');
    if (path.startsWith('/diagnostics')) return t('title.diagnostics', 'Diagnostic Workspace');
    if (path.startsWith('/training')) return t('title.training', 'Vocational Training Studio');
    if (path.startsWith('/devices')) return t('title.devices', 'Device Fleet Management');
    if (path.startsWith('/sessions')) return t('title.sessions', 'Training Sessions');
    if (path.startsWith('/trainees')) return t('title.trainees', 'Trainee Directory');
    if (path.startsWith('/assessments')) return t('title.assessments', 'NSQF Skill Assessments');
    if (path.startsWith('/alerts')) return t('title.alerts', 'Hazard Alerts Log');
    if (path.startsWith('/bom')) return t('title.bom', 'Hardware Procurement & BOM');
    return 'Dashboard';
  })();

  return (
    <div className="hg-layout">
      {/* Sidebar */}
      <aside className={`hg-sidebar ${mobileMenuOpen ? 'open' : ''}`}>
        {/* Brand */}
        <div className="hg-sidebar-brand">
          <div className="hg-sidebar-wordmark">
            HAZE<span className="hg-sidebar-accent">GUARD</span>
          </div>
          <div className="hg-sidebar-sub">NAADYANTRA SIH26244</div>
        </div>

        {/* Navigation */}
        <nav className="hg-sidebar-nav">
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.exact}
              className={({ isActive }) =>
                `hg-sidebar-link${isActive ? ' active' : ''}`
              }
              onClick={() => setMobileMenuOpen(false)}
            >
              {item.icon}
              {t(item.key, item.label)}
            </NavLink>
          ))}
        </nav>

        {/* Footer */}
        <div className="hg-sidebar-footer">
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '0 12px 10px', fontSize: 11, color: 'rgba(255,255,255,0.45)' }}>
            <span className="hg-dot hg-dot-ok" style={{ width: 6, height: 6 }} />
            <span>{t('nav.role', 'Role: Trainer / Assessor')}</span>
          </div>
          <button className="hg-sidebar-logout" onClick={handleLogout}>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M6 14H3a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1h3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
              <path d="M11 11l3-3-3-3M14 8H6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            {t('nav.signout', 'Sign Out')}
          </button>
        </div>
      </aside>

      {/* Main area */}
      <div className="hg-main">
        {/* Top bar */}
        <header className="hg-topbar">
          <button
            className="hg-btn hg-btn-ghost md:hidden"
            style={{ display: 'none', padding: 4 }}
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          >
            ☰
          </button>

          <div style={{ flex: 1 }}>
            <span className="hg-topbar-title">{pageTitle}</span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            {/* Hindi / English Language Switcher */}
            <button
              className="hg-btn hg-btn-secondary"
              onClick={toggleLang}
              style={{
                fontSize: 11,
                padding: '4px 10px',
                height: 30,
                borderRadius: 99,
                fontWeight: 700,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 5,
              }}
              title={lang === 'en' ? 'हिंदी में बदलें (Switch to Hindi)' : 'Switch to English'}
              aria-label="Toggle Language"
            >
              <span style={{ fontSize: 13 }}>🌐</span>
              <span>{lang === 'en' ? 'हिंदी' : 'EN'}</span>
            </button>

            {/* Demo Mode Toggle */}
            <button
              onClick={toggleDemoMode}
              className={`hg-btn ${isDemoMode ? 'hg-btn-primary' : 'hg-btn-secondary'}`}
              style={{
                fontSize: 11,
                padding: '4px 10px',
                height: 30,
                borderRadius: 99,
                fontWeight: 700,
              }}
              title={isDemoMode ? 'Click to switch to live production backend' : 'Click to enable isolated offline demo mode'}
            >
              {isDemoMode ? t('mode.demo_on', '🧪 Demo Mode: ON') : t('mode.live', 'Live Backend')}
            </button>

            {/* Light / Dark Mode Toggle */}
            <button
              className="hg-theme-btn"
              onClick={toggleTheme}
              title={`Switch to ${theme === 'light' ? 'Dark' : 'Light'} Mode`}
              aria-label="Toggle Theme"
            >
              {theme === 'light' ? (
                /* Moon Icon */
                <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <path d="M14 9.5A6.5 6.5 0 1 1 6.5 2 5 5 0 0 0 14 9.5z" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              ) : (
                /* Sun Icon */
                <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <circle cx="8" cy="8" r="3.5"/>
                  <path d="M8 1v2M8 13v2M1 8h2M13 8h2M3.05 3.05l1.41 1.41M11.54 11.54l1.41 1.41M3.05 12.95l1.41-1.41M11.54 4.46l1.41-1.41"/>
                </svg>
              )}
            </button>

            {/* Platform Tag */}
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              fontSize: 11,
              color: 'var(--color-warm-graphite)',
              background: 'var(--color-warm-stone)',
              padding: '4px 8px',
              borderRadius: 6,
            }}>
              <span className="hg-dot hg-dot-ok hg-dot-pulse" style={{ width: 6, height: 6 }} />
              <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 600 }}>
                PS26244
              </span>
            </div>
          </div>
        </header>

        {/* Persistent Demo Mode Banner */}
        {isDemoMode && (
          <div className="hg-demo-banner">
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span className="hg-demo-pill">DEMO / SIMULATED</span>
              <span>Isolated Client Fixtures Active · Zero Production API Ingestion · Deterministic Diagnostics</span>
            </div>
            <button className="hg-demo-exit" onClick={toggleDemoMode}>
              Exit Demo Mode
            </button>
          </div>
        )}

        {/* Page content */}
        <main className="hg-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}

export default Layout;
