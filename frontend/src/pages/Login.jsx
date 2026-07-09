import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { HeartPulse, Mail, Lock, ArrowRight, Loader2, Eye, EyeOff, Wifi, WifiOff } from 'lucide-react';
import api from '../utils/api';
import { signInWithGoogle } from '../utils/firebase';
import { useAuth } from '../contexts/AuthContext';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [loading, setLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [error, setError] = useState('');
  const [serverStatus, setServerStatus] = useState('checking'); // 'checking' | 'online' | 'waking'

  const navigate = useNavigate();
  const { login } = useAuth();

  // Ping backend on mount to check/wake server
  useEffect(() => {
    const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
    const checkServer = async () => {
      try {
        const res = await fetch(`${apiBaseUrl}/api/health/`, { signal: AbortSignal.timeout(5000) });
        if (res.ok) {
          setServerStatus('online');
        } else {
          setServerStatus('waking');
        }
      } catch {
        setServerStatus('waking');
        // Retry after 5s — Render needs time to wake
        setTimeout(async () => {
          try {
            await fetch(`${apiBaseUrl}/api/health/`);
            setServerStatus('online');
          } catch {
            setServerStatus('online'); // Stop showing warning after retry
          }
        }, 8000);
      }
    };
    checkServer();
  }, []);

  // ─────────────────────── Google ───────────────────────
  const handleGoogleLogin = async () => {
    setGoogleLoading(true);
    setError('');
    try {
      const user = await signInWithGoogle();
      const idToken = await user.getIdToken();
      localStorage.setItem('access_token', idToken);
      localStorage.setItem('refresh_token', idToken);
      localStorage.setItem('username', user.displayName || user.email?.split('@')[0] || 'User');
      localStorage.setItem('user_id', user.uid);
      localStorage.setItem('auth_provider', 'google');
      navigate('/');
    } catch (err) {
      console.error(err);
      setError(`Google Sign-In failed: ${err.message || 'Unknown error'}`);
    } finally {
      setGoogleLoading(false);
    }
  };

  // ─────────────────────── Email/Password Login ───────────────────────
  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const response = await api.post('/token/', {
        username: email.trim(),
        password: password.trim(),
      });
      const userData = {
        access: response.data.access,
        refresh: response.data.refresh,
        username: response.data.username || email.split('@')[0],
        user_id: response.data.user_id?.toString() || '',
        role: response.data.role || 'MEMBER',
      };
      if (rememberMe) {
        localStorage.setItem('remembered_email', email.trim());
      } else {
        localStorage.removeItem('remembered_email');
      }
      login(userData);
      navigate('/');
    } catch (err) {
      if (!err.response) {
        setError('Server is unreachable. Please wait a moment and try again — the server may be waking up.');
      } else if (err.response.status === 401) {
        setError('Incorrect username/email or password. Please check and try again.');
      } else if (err.response.status === 429) {
        setError('Too many login attempts. Please wait a few minutes before trying again.');
      } else {
        setError(`Login failed: ${err.response?.data?.detail || 'Unknown error. Please try again.'}`);
      }
    } finally {
      setLoading(false);
    }
  };

  // Pre-fill remembered email
  useEffect(() => {
    const remembered = localStorage.getItem('remembered_email');
    if (remembered) {
      setEmail(remembered);
      setRememberMe(true);
    }
  }, []);

  return (
    <div className="min-h-screen bg-navy-900 flex flex-col md:items-center md:justify-center p-4 md:p-6 relative overflow-hidden">
      <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-brand-500/20 rounded-full blur-[120px] animate-pulse"></div>
      <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-blue-500/20 rounded-full blur-[120px] animate-pulse" style={{ animationDelay: '1s' }}></div>

      <div className="w-full max-w-md relative z-10">
        {/* Logo */}
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-brand-500 rounded-2xl shadow-lg shadow-brand-500/30 mb-4 transform hover:rotate-12 transition-transform duration-300">
            <HeartPulse className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-white tracking-tight">Welcome Back</h1>
          <p className="text-navy-400 mt-2">Sign in to your family health dashboard</p>
        </div>

        {/* Server status banner */}
        {serverStatus === 'waking' && (
          <div className="mb-4 p-3 bg-amber-500/20 border border-amber-500/40 rounded-2xl flex items-center space-x-3 text-amber-200 text-sm">
            <Loader2 className="w-4 h-4 animate-spin shrink-0" />
            <span>Server is waking up — this takes about 30 seconds on first visit. Please wait...</span>
          </div>
        )}
        {serverStatus === 'online' && (
          <div className="mb-4 p-3 bg-emerald-500/20 border border-emerald-500/40 rounded-2xl flex items-center space-x-3 text-emerald-200 text-sm">
            <Wifi className="w-4 h-4 shrink-0" />
            <span>Server is online and ready.</span>
          </div>
        )}

        <div className="bg-white/10 backdrop-blur-xl border border-white/10 p-8 rounded-[2rem] shadow-2xl">
          {error && (
            <div className="mb-6 p-4 bg-red-500/20 border border-red-500/50 rounded-xl text-red-200 text-sm flex items-start space-x-2">
              <WifiOff className="w-4 h-4 mt-0.5 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleLogin} className="space-y-5">
            {/* Username / Email */}
            <div className="space-y-2">
              <label className="text-sm font-medium text-navy-200 ml-1">Username or Email</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400 transition-colors">
                  <Mail className="w-5 h-5" />
                </div>
                <input
                  id="login-email"
                  type="text"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  autoComplete="username"
                  className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 focus:border-brand-500 transition-all"
                  placeholder="username or name@example.com"
                />
              </div>
            </div>

            {/* Password */}
            <div className="space-y-2">
              <div className="flex justify-between items-center ml-1">
                <label className="text-sm font-medium text-navy-200">Password</label>
                <Link to="/forgot-password" className="text-xs text-brand-400 hover:text-brand-300 transition-colors">Forgot password?</Link>
              </div>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400 transition-colors">
                  <Lock className="w-5 h-5" />
                </div>
                <input
                  id="login-password"
                  type={showPassword ? 'text' : 'password'}
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                  className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-12 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 focus:border-brand-500 transition-all"
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 pr-4 flex items-center text-navy-400 hover:text-brand-400 transition-colors"
                >
                  {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>
            </div>

            {/* Remember me */}
            <div className="flex items-center space-x-2">
              <input
                id="remember"
                type="checkbox"
                checked={rememberMe}
                onChange={(e) => setRememberMe(e.target.checked)}
                className="w-4 h-4 rounded accent-brand-500 cursor-pointer"
              />
              <label htmlFor="remember" className="text-sm text-navy-300 cursor-pointer">Remember me</label>
            </div>

            {/* Submit */}
            <button
              type="submit"
              id="login-submit"
              disabled={loading || serverStatus === 'waking'}
              className="w-full bg-brand-500 hover:bg-brand-600 disabled:opacity-60 disabled:cursor-not-allowed text-white font-bold py-4 rounded-2xl shadow-lg shadow-brand-500/30 transform hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center group mt-2"
            >
              {loading ? (
                <><Loader2 className="w-5 h-5 animate-spin mr-2" /><span>Signing in...</span></>
              ) : serverStatus === 'waking' ? (
                <><Loader2 className="w-5 h-5 animate-spin mr-2" /><span>Waiting for server...</span></>
              ) : (
                <>Sign In<ArrowRight className="w-5 h-5 ml-2 group-hover:translate-x-1 transition-transform" /></>
              )}
            </button>

            {/* Divider */}
            <div className="relative my-4">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-white/10"></div>
              </div>
              <div className="relative flex justify-center text-xs uppercase">
                <span className="bg-transparent px-2 text-navy-500 font-bold tracking-widest">Or continue with</span>
              </div>
            </div>

            {/* Google */}
            <button
              type="button"
              onClick={handleGoogleLogin}
              disabled={googleLoading}
              className="w-full bg-white/5 hover:bg-white/10 border border-white/10 text-white font-bold py-4 rounded-2xl transition-all flex items-center justify-center space-x-3"
            >
              {googleLoading ? <Loader2 className="w-5 h-5 animate-spin" /> : (
                <img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/action/google.svg" className="w-5 h-5" alt="Google" />
              )}
              <span>Sign in with Google</span>
            </button>
          </form>

          <div className="mt-6 text-center">
            <p className="text-navy-400 text-sm">
              Don't have an account?{' '}
              <Link to="/register" className="text-brand-400 font-bold hover:text-brand-300 transition-colors">Create account</Link>
            </p>
          </div>
        </div>

        <div className="mt-6 flex justify-center space-x-6 text-navy-500 text-xs font-medium uppercase tracking-widest">
          <span className="hover:text-navy-300 cursor-pointer transition-colors">Privacy Policy</span>
          <span>•</span>
          <span className="hover:text-navy-300 cursor-pointer transition-colors">Terms of Service</span>
        </div>
      </div>
    </div>
  );
}
