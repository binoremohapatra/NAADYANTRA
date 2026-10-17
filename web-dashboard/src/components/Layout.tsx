import { Outlet, Link, useNavigate } from 'react-router-dom';
import { apiClient } from '../api/client';

interface LayoutProps {
  onLogout: () => void;
}

function Layout({ onLogout }: LayoutProps) {
  const navigate = useNavigate();

  const handleLogout = async () => {
    try {
      await apiClient.logout();
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      localStorage.removeItem('auth_token');
      onLogout();
      navigate('/login');
    }
  };

  return (
    <div className="min-h-screen bg-offWhite">
      {/* Header */}
      <header className="bg-white border-b border-warmStone">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <h1 className="text-2xl font-bold text-obsidian tracking-tight">
                NAADYANTRA
              </h1>
              <span className="ml-4 text-sm text-warmGraphite">Admin Console</span>
            </div>
            <nav className="flex space-x-6">
              <Link
                to="/"
                className="text-warmGraphite hover:text-burntOrange font-medium transition-colors"
              >
                Overview
              </Link>
              <Link
                to="/devices"
                className="text-warmGraphite hover:text-burntOrange font-medium transition-colors"
              >
                Devices
              </Link>
              <Link
                to="/sessions"
                className="text-warmGraphite hover:text-burntOrange font-medium transition-colors"
              >
                Sessions
              </Link>
              <Link
                to="/trainees"
                className="text-warmGraphite hover:text-burntOrange font-medium transition-colors"
              >
                Trainees
              </Link>
              <Link
                to="/assessments"
                className="text-warmGraphite hover:text-burntOrange font-medium transition-colors"
              >
                Assessments
              </Link>
              <Link
                to="/alerts"
                className="text-warmGraphite hover:text-burntOrange font-medium transition-colors"
              >
                Alerts
              </Link>
            </nav>
            <button
              onClick={handleLogout}
              className="px-4 py-2 text-sm text-warmGraphite hover:text-obsidian transition-colors"
            >
              Logout
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Outlet />
      </main>
    </div>
  );
}

export default Layout;
