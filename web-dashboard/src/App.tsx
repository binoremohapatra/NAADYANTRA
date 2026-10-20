import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { useState, useEffect } from 'react';
import { ThemeProvider } from './context/ThemeContext';
import { LanguageProvider } from './context/LanguageContext';
import { DemoProvider } from './context/DemoContext';
import Layout from './components/Layout';
import Login from './pages/Login';
import Overview from './pages/Overview';
import Diagnostics from './pages/Diagnostics';
import TrainingWorkflow from './pages/TrainingWorkflow';
import Devices from './pages/Devices';
import DeviceDetail from './pages/DeviceDetail';
import Alerts from './pages/Alerts';
import Sessions from './pages/Sessions';
import Trainees from './pages/Trainees';
import Assessments from './pages/Assessments';
import LiveFeed from './pages/LiveFeed';
import BomProcurement from './pages/BomProcurement';

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('auth_token');
    setIsAuthenticated(!!token);
    setIsLoading(false);
  }, []);

  if (isLoading) {
    return (
      <div className="hg-loading-screen" style={{ minHeight: '100vh', background: 'var(--color-ivory)' }}>
        <div className="hg-spinner" />
        <div style={{ color: 'var(--color-warm-graphite)', fontSize: 13 }}>Initializing HazeGuard Console…</div>
      </div>
    );
  }

  return (
    <ThemeProvider>
      <LanguageProvider>
        <DemoProvider>
          <Router>
            <Routes>
              <Route
                path="/login"
                element={
                  isAuthenticated ? (
                    <Navigate to="/" replace />
                  ) : (
                    <Login onLogin={() => setIsAuthenticated(true)} />
                  )
                }
              />
              <Route
                path="/"
                element={
                  isAuthenticated ? (
                    <Layout onLogout={() => setIsAuthenticated(false)} />
                  ) : (
                    <Navigate to="/login" replace />
                  )
                }
              >
                <Route index element={<Overview />} />
                <Route path="feed" element={<LiveFeed />} />
                <Route path="diagnostics" element={<Diagnostics />} />
                <Route path="training" element={<TrainingWorkflow />} />
                <Route path="devices" element={<Devices />} />
                <Route path="devices/:deviceId" element={<DeviceDetail />} />
                <Route path="sessions" element={<Sessions />} />
                <Route path="trainees" element={<Trainees />} />
                <Route path="assessments" element={<Assessments />} />
                <Route path="alerts" element={<Alerts />} />
                <Route path="bom" element={<BomProcurement />} />
              </Route>
            </Routes>
          </Router>
        </DemoProvider>
      </LanguageProvider>
    </ThemeProvider>
  );
}

export default App;
