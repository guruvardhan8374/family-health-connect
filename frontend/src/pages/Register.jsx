import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { HeartPulse, Mail, Lock, User, ShieldCheck, ArrowRight, Loader2, Eye, EyeOff, Check, X, Wifi } from 'lucide-react';
import api from '../utils/api';
import { useAuth } from '../contexts/AuthContext';

// Password strength rules
const rules = [
  { id: 'length',  label: 'At least 8 characters',         test: (p) => p.length >= 8 },
  { id: 'upper',   label: 'One uppercase letter',           test: (p) => /[A-Z]/.test(p) },
  { id: 'lower',   label: 'One lowercase letter',           test: (p) => /[a-z]/.test(p) },
  { id: 'number',  label: 'One number',                     test: (p) => /\d/.test(p) },
  { id: 'special', label: 'One special character (@#$!%*)', test: (p) => /[@#$!%*?&^()_\-+=]/.test(p) },
];

function strengthLabel(score) {
  if (score <= 1) return { label: 'Very Weak', color: 'bg-red-500' };
  if (score === 2) return { label: 'Weak',      color: 'bg-orange-500' };
  if (score === 3) return { label: 'Fair',       color: 'bg-yellow-500' };
  if (score === 4) return { label: 'Strong',     color: 'bg-blue-500' };
  return              { label: 'Very Strong', color: 'bg-emerald-500' };
}

export default function Register() {
  const [formData, setFormData] = useState({ username: '', email: '', password: '', confirmPassword: '', role: 'MEMBER' });
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm]   = useState(false);
  const [loading, setLoading]           = useState(false);
  const [error, setError]               = useState('');
  const [serverStatus, setServerStatus] = useState('checking');

  const navigate = useNavigate();
  const { login } = useAuth();

  const passScore   = rules.filter(r => r.test(formData.password)).length;
  const strength    = strengthLabel(passScore);
  const passMatch   = formData.confirmPassword.length > 0 && formData.password === formData.confirmPassword;
  const passMismatch = formData.confirmPassword.length > 0 && formData.password !== formData.confirmPassword;

  // Wake-up ping
  useEffect(() => {
    const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
    fetch(`${apiBaseUrl}/api/health/`, { signal: AbortSignal.timeout(5000) })
      .then(r => r.ok ? setServerStatus('online') : setServerStatus('waking'))
      .catch(() => {
        setServerStatus('waking');
        setTimeout(() => fetch(`${apiBaseUrl}/api/health/`).then(() => setServerStatus('online')).catch(() => setServerStatus('online')), 8000);
      });
  }, []);

  const handleChange = (e) => setFormData({ ...formData, [e.target.name]: e.target.value });

  const handleRegister = async (e) => {
    e.preventDefault();
    if (passMismatch || formData.confirmPassword === '') {
      setError('Passwords do not match.');
      return;
    }
    if (passScore < 3) {
      setError('Password is too weak. Please make it stronger.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const res = await api.post('/users/register/', {
        username:         formData.username.trim(),
        email:            formData.email.trim(),
        password:         formData.password,
        password_confirm: formData.password,
        role:             formData.role,
      });
      const data = res.data;
      if (data.access && data.refresh) {
        login({
          access:   data.access,
          refresh:  data.refresh,
          username: data.username || formData.username,
          user_id:  data.user_id?.toString() || '',
          role:     data.role || formData.role,
        });
        navigate('/');
      } else {
        navigate('/verify-otp', { state: { email: formData.email } });
      }
    } catch (err) {
      if (!err.response) {
        setError('Server is unreachable. It may be waking up — please wait 30 seconds and try again.');
      } else {
        const data = err.response.data;
        if (data?.email)    setError(`Email: ${Array.isArray(data.email) ? data.email[0] : data.email}`);
        else if (data?.username) setError(`Username: ${Array.isArray(data.username) ? data.username[0] : data.username}`);
        else if (data?.password) setError(`Password: ${Array.isArray(data.password) ? data.password[0] : data.password}`);
        else if (data?.message) setError(data.message);
        else if (data?.detail)  setError(data.detail);
        else setError('Registration failed. Please check your details and try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-navy-900 flex flex-col md:items-center md:justify-center p-4 md:p-6 relative overflow-hidden">
      <div className="absolute top-[-10%] right-[-10%] w-[40%] h-[40%] bg-emerald-500/20 rounded-full blur-[120px] animate-pulse"></div>
      <div className="absolute bottom-[-10%] left-[-10%] w-[40%] h-[40%] bg-brand-500/20 rounded-full blur-[120px] animate-pulse" style={{ animationDelay: '1.5s' }}></div>

      <div className="w-full max-w-lg relative z-10">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-brand-500 rounded-2xl shadow-lg shadow-brand-500/30 mb-4 transform hover:scale-110 transition-transform duration-300">
            <HeartPulse className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-white tracking-tight">Join FamilyConnect</h1>
          <p className="text-navy-400 mt-2">Start monitoring your family's health today</p>
        </div>

        {/* Server status */}
        {serverStatus === 'waking' && (
          <div className="mb-4 p-3 bg-amber-500/20 border border-amber-500/40 rounded-2xl flex items-center space-x-3 text-amber-200 text-sm">
            <Loader2 className="w-4 h-4 animate-spin shrink-0" />
            <span>Server is waking up — please wait ~30 seconds before registering...</span>
          </div>
        )}
        {serverStatus === 'online' && (
          <div className="mb-4 p-3 bg-emerald-500/20 border border-emerald-500/40 rounded-2xl flex items-center space-x-3 text-emerald-200 text-sm">
            <Wifi className="w-4 h-4 shrink-0" />
            <span>Server is online. Ready to register!</span>
          </div>
        )}

        <div className="bg-white/10 backdrop-blur-xl border border-white/10 p-8 rounded-[2.5rem] shadow-2xl">
          {error && (
            <div className="mb-6 p-4 bg-red-500/20 border border-red-500/50 rounded-xl text-red-200 text-sm">
              {error}
            </div>
          )}

          <form onSubmit={handleRegister} className="grid grid-cols-1 md:grid-cols-2 gap-5">

            {/* Username */}
            <div className="space-y-2">
              <label className="text-sm font-medium text-navy-200 ml-1">Username</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400">
                  <User className="w-5 h-5" />
                </div>
                <input
                  name="username"
                  required
                  autoComplete="username"
                  value={formData.username}
                  onChange={handleChange}
                  className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
                  placeholder="vardhan_dev"
                />
              </div>
            </div>

            {/* Email */}
            <div className="space-y-2">
              <label className="text-sm font-medium text-navy-200 ml-1">Email</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400">
                  <Mail className="w-5 h-5" />
                </div>
                <input
                  name="email"
                  type="email"
                  required
                  autoComplete="email"
                  value={formData.email}
                  onChange={handleChange}
                  className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
                  placeholder="name@example.com"
                />
              </div>
            </div>

            {/* Role */}
            <div className="space-y-2 md:col-span-2">
              <label className="text-sm font-medium text-navy-200 ml-1">Your Role in Family</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400">
                  <ShieldCheck className="w-5 h-5" />
                </div>
                <select
                  name="role"
                  value={formData.role}
                  onChange={handleChange}
                  className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white appearance-none focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
                >
                  <option value="MEMBER" className="bg-navy-900">Family Member</option>
                  <option value="HEAD"   className="bg-navy-900">Family Head</option>
                </select>
              </div>
            </div>

            {/* Password */}
            <div className="space-y-2 md:col-span-2">
              <label className="text-sm font-medium text-navy-200 ml-1">Password</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400">
                  <Lock className="w-5 h-5" />
                </div>
                <input
                  name="password"
                  type={showPassword ? 'text' : 'password'}
                  required
                  autoComplete="new-password"
                  value={formData.password}
                  onChange={handleChange}
                  className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-12 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
                  placeholder="••••••••"
                />
                <button type="button" onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 pr-4 flex items-center text-navy-400 hover:text-brand-400 transition-colors">
                  {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>

              {/* Strength bar */}
              {formData.password.length > 0 && (
                <div className="mt-2 space-y-2">
                  <div className="flex space-x-1">
                    {[1,2,3,4,5].map(i => (
                      <div key={i} className={`h-1.5 flex-1 rounded-full transition-all duration-300 ${i <= passScore ? strength.color : 'bg-white/10'}`} />
                    ))}
                  </div>
                  <p className="text-xs text-navy-400">Strength: <span className="font-bold text-white">{strength.label}</span></p>
                  <div className="grid grid-cols-2 gap-1">
                    {rules.map(r => (
                      <div key={r.id} className={`flex items-center space-x-1.5 text-xs ${r.test(formData.password) ? 'text-emerald-400' : 'text-navy-500'}`}>
                        {r.test(formData.password) ? <Check className="w-3 h-3" /> : <X className="w-3 h-3" />}
                        <span>{r.label}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>

            {/* Confirm Password */}
            <div className="space-y-2 md:col-span-2">
              <label className="text-sm font-medium text-navy-200 ml-1">Confirm Password</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400">
                  <Lock className="w-5 h-5" />
                </div>
                <input
                  name="confirmPassword"
                  type={showConfirm ? 'text' : 'password'}
                  required
                  autoComplete="new-password"
                  value={formData.confirmPassword}
                  onChange={handleChange}
                  className={`w-full bg-navy-800/50 border rounded-2xl py-3 pl-12 pr-12 text-white placeholder-navy-500 focus:outline-none focus:ring-2 transition-all ${
                    passMatch    ? 'border-emerald-500/50 focus:ring-emerald-500/50' :
                    passMismatch ? 'border-red-500/50 focus:ring-red-500/50' :
                    'border-white/5 focus:ring-brand-500/50'
                  }`}
                  placeholder="••••••••"
                />
                <button type="button" onClick={() => setShowConfirm(!showConfirm)}
                  className="absolute inset-y-0 right-0 pr-4 flex items-center text-navy-400 hover:text-brand-400 transition-colors">
                  {showConfirm ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
                {passMatch    && <Check className="absolute right-12 top-1/2 -translate-y-1/2 w-4 h-4 text-emerald-400" />}
                {passMismatch && <X     className="absolute right-12 top-1/2 -translate-y-1/2 w-4 h-4 text-red-400" />}
              </div>
              {passMismatch && <p className="text-xs text-red-400 ml-1">Passwords do not match</p>}
              {passMatch    && <p className="text-xs text-emerald-400 ml-1">Passwords match ✓</p>}
            </div>

            {/* Submit */}
            <button
              type="submit"
              disabled={loading || passMismatch || serverStatus === 'waking'}
              className="w-full md:col-span-2 bg-brand-500 hover:bg-brand-600 disabled:opacity-60 disabled:cursor-not-allowed text-white font-bold py-4 rounded-2xl shadow-lg shadow-brand-500/30 transform hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center group mt-2"
            >
              {loading ? (
                <><Loader2 className="w-5 h-5 animate-spin mr-2" /><span>Creating account...</span></>
              ) : serverStatus === 'waking' ? (
                <><Loader2 className="w-5 h-5 animate-spin mr-2" /><span>Waiting for server...</span></>
              ) : (
                <>Create Account<ArrowRight className="w-5 h-5 ml-2 group-hover:translate-x-1 transition-transform" /></>
              )}
            </button>
          </form>

          <div className="mt-6 text-center">
            <p className="text-navy-400 text-sm">
              Already have an account?{' '}
              <Link to="/login" className="text-brand-400 font-bold hover:text-brand-300 transition-colors">Sign in</Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
