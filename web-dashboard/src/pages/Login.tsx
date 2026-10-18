import { useState } from 'react';
import { apiClient } from '../api/client';

interface LoginProps {
  onLogin: () => void;
}

function Login({ onLogin }: LoginProps) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      const { access_token } = await apiClient.login(username, password);
      localStorage.setItem('auth_token', access_token);
      onLogin();
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Authentication failed. Check credentials and try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'var(--color-carbon)',
      padding: 24,
      position: 'relative',
      overflow: 'hidden',
    }}>
      {/* Background texture pattern */}
      <div style={{
        position: 'absolute',
        inset: 0,
        backgroundImage: `radial-gradient(circle at 20% 80%, rgba(240,120,66,0.08) 0%, transparent 50%),
                          radial-gradient(circle at 80% 20%, rgba(240,120,66,0.05) 0%, transparent 50%)`,
        pointerEvents: 'none',
      }} />

      {/* Grid overlay */}
      <div style={{
        position: 'absolute',
        inset: 0,
        backgroundImage: `linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px),
                          linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px)`,
        backgroundSize: '48px 48px',
        pointerEvents: 'none',
      }} />

      <div style={{ width: '100%', maxWidth: 420, position: 'relative', zIndex: 1 }}>
        {/* Card */}
        <div style={{
          background: 'var(--color-white)',
          borderRadius: 'var(--radius-xl)',
          boxShadow: 'var(--shadow-modal)',
          overflow: 'hidden',
        }}>
          {/* Brand header */}
          <div style={{
            padding: '32px 36px 28px',
            borderBottom: '1px solid var(--color-warm-stone)',
            background: 'var(--color-ivory)',
          }}>
            <div style={{
              fontSize: 26,
              fontWeight: 800,
              letterSpacing: '0.14em',
              color: 'var(--color-carbon)',
            }}>
              HAZE<span style={{ color: 'var(--color-burnt-orange)' }}>GUARD</span>
            </div>
            <div style={{
              fontSize: 12,
              fontWeight: 500,
              letterSpacing: '0.06em',
              color: 'var(--color-warm-graphite)',
              textTransform: 'uppercase',
              marginTop: 4,
            }}>
              AI Diagnostic Wearables · Admin Console
            </div>
          </div>

          {/* Form */}
          <div style={{ padding: '28px 36px 32px' }}>
            <div style={{ marginBottom: 24 }}>
              <p style={{
                fontSize: 14,
                fontWeight: 600,
                color: 'var(--color-carbon)',
                margin: '0 0 4px',
              }}>Sign in to continue</p>
              <p style={{
                fontSize: 13,
                color: 'var(--color-warm-graphite)',
                margin: 0,
              }}>
                Authorised personnel only. All access is logged.
              </p>
            </div>

            {error && (
              <div className="hg-alert hg-alert-error" style={{ marginBottom: 20 }}>
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ flexShrink: 0, marginTop: 1 }}>
                  <circle cx="8" cy="8" r="7" stroke="currentColor" strokeWidth="1.5"/>
                  <path d="M8 5v3.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
                  <circle cx="8" cy="11" r="0.75" fill="currentColor"/>
                </svg>
                {error}
              </div>
            )}

            <form onSubmit={handleSubmit}>
              <div className="hg-form-group">
                <label htmlFor="login-username" className="hg-label">Username</label>
                <input
                  id="login-username"
                  type="text"
                  className="hg-input"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="Enter your username"
                  autoComplete="username"
                  required
                />
              </div>

              <div className="hg-form-group" style={{ marginBottom: 24 }}>
                <label htmlFor="login-password" className="hg-label">Password</label>
                <div style={{ position: 'relative' }}>
                  <input
                    id="login-password"
                    type={showPassword ? 'text' : 'password'}
                    className="hg-input"
                    style={{ paddingRight: 44 }}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Enter your password"
                    autoComplete="current-password"
                    required
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    style={{
                      position: 'absolute',
                      right: 12,
                      top: '50%',
                      transform: 'translateY(-50%)',
                      background: 'none',
                      border: 'none',
                      cursor: 'pointer',
                      color: 'var(--color-warm-graphite)',
                      padding: 0,
                      display: 'flex',
                      alignItems: 'center',
                    }}
                    tabIndex={-1}
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? (
                      <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                        <path d="M1 1l14 14M6.5 6.5A2 2 0 0 0 9.5 9.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
                        <path d="M3.5 3.5C2 4.8 1 6.3 1 8c0 2.8 3.1 5 7 5 1.5 0 3-.4 4.2-1.1M5 2.3A8.5 8.5 0 0 1 8 2c3.9 0 7 2.2 7 6a6.4 6.4 0 0 1-.8 2.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
                      </svg>
                    ) : (
                      <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                        <path d="M1 8c0-2.8 3.1-6 7-6s7 3.2 7 6-3.1 6-7 6-7-3.2-7-6z" stroke="currentColor" strokeWidth="1.5"/>
                        <circle cx="8" cy="8" r="2" stroke="currentColor" strokeWidth="1.5"/>
                      </svg>
                    )}
                  </button>
                </div>
              </div>

              <button
                id="login-submit"
                type="submit"
                disabled={isLoading}
                className="hg-btn hg-btn-primary"
                style={{ width: '100%', padding: '11px 16px', fontSize: 14 }}
              >
                {isLoading ? (
                  <>
                    <span className="hg-spinner" style={{ width: 16, height: 16, borderWidth: 2 }} />
                    Authenticating…
                  </>
                ) : (
                  <>
                    Sign In
                    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                      <path d="M3 7h8M8 4l3 3-3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  </>
                )}
              </button>
            </form>
          </div>
        </div>

        {/* Footer text */}
        <p style={{
          textAlign: 'center',
          fontSize: 11,
          color: 'rgba(255,255,255,0.3)',
          marginTop: 20,
          letterSpacing: '0.04em',
        }}>
          NAADYANTRA SIH26244 · Secure Channel
        </p>
      </div>
    </div>
  );
}

export default Login;
