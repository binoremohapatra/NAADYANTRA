import { Outlet, NavLink, useNavigate, useLocation } from 'react-router-dom';
import { apiClient } from '../api/client';

interface LayoutProps {
  onLogout: () => void;
}

const NAV_ITEMS = [
  {
    to: '/',
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
    to: '/devices',
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
    label: 'Alerts',
    icon: (
      <svg className="hg-nav-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M8 1L1.5 13h13L8 1z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
        <path d="M8 6v3.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
        <circle cx="8" cy="11.5" r="0.75" fill="currentColor"/>
      </svg>
    ),
  },
];

function Layout({ onLogout }: LayoutProps) {
  const navigate = useNavigate();
  const location = useLocation();

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
    if (path === '/') return 'Overview';
    if (path.startsWith('/devices')) return 'Device Management';
    if (path.startsWith('/sessions')) return 'Training Sessions';
    if (path.startsWith('/trainees')) return 'Trainee Directory';
    if (path.startsWith('/assessments')) return 'Assessments & Rubrics';
    if (path.startsWith('/alerts')) return 'Hazard Alerts';
    return 'Dashboard';
  })();

  return (
    <div className="hg-layout">
      {/* Sidebar */}
      <aside className="hg-sidebar">
        {/* Brand */}
        <div className="hg-sidebar-brand">
          <div className="hg-sidebar-wordmark">
            HAZE<span className="hg-sidebar-accent">GUARD</span>
          </div>
          <div className="hg-sidebar-sub">Admin Console</div>
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
            >
              {item.icon}
              {item.label}
            </NavLink>
          ))}
        </nav>

        {/* Footer */}
        <div className="hg-sidebar-footer">
          <button className="hg-sidebar-logout" onClick={handleLogout}>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M6 14H3a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1h3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
              <path d="M11 11l3-3-3-3M14 8H6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main area */}
      <div className="hg-main">
        {/* Top bar */}
        <header className="hg-topbar">
          <div style={{ flex: 1 }}>
            <span className="hg-topbar-title">{pageTitle}</span>
          </div>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            fontSize: 12,
            color: 'var(--color-warm-graphite)'
          }}>
            <span className="hg-dot hg-dot-ok hg-dot-pulse" style={{ width: 6, height: 6 }} />
            <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 500 }}>
              SIH26244
            </span>
          </div>
        </header>

        {/* Page content */}
        <main className="hg-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}

export default Layout;
