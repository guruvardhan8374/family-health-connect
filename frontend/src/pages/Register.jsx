import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { HeartPulse, Mail, Lock, User, ShieldCheck, ArrowRight, Loader2 } from 'lucide-react';
import api from '../utils/api';
import { useAuth } from '../contexts/AuthContext';

export default function Register() {
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: '',
    role: 'MEMBER'
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const navigate = useNavigate();
  const { login } = useAuth();

  const handleRegister = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const registrationData = {
        ...formData,
        password_confirm: formData.password
      };
      const res = await api.post('/users/register/', registrationData);
      const data = res.data;
      // If backend returns tokens (auto-verify mode), log in immediately
      if (data.access && data.refresh) {
        login({
          access: data.access,
          refresh: data.refresh,
          username: data.username || formData.username,
          user_id: data.user_id?.toString() || '',
        });
        navigate('/');
      } else {
        // Fallback: redirect to OTP verification
        navigate('/verify-otp', { state: { email: formData.email } });
      }
    } catch (err) {
      let errorMsg = 'Registration failed. Please check your details.';
      if (err.response?.data) {
        const data = err.response.data;
        if (data.message) {
          errorMsg = data.message;
        } else if (typeof data === 'object') {
          const errors = Object.entries(data).map(([field, msgs]) => {
            const fieldName = field.charAt(0).toUpperCase() + field.slice(1).replace('_', ' ');
            const messages = Array.isArray(msgs) ? msgs.join(' ') : msgs;
            return `${fieldName}: ${messages}`;
          });
          if (errors.length > 0) {
            errorMsg = errors.join(' | ');
          }
        }
      }
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  return (
    <div className="min-h-screen bg-navy-900 flex flex-col md:items-center md:justify-center p-4 md:p-6 relative overflow-hidden">
      {/* Background Blobs */}
      <div className="absolute top-[-10%] right-[-10%] w-[40%] h-[40%] bg-emerald-500/20 rounded-full blur-[120px] animate-pulse"></div>
      <div className="absolute bottom-[-10%] left-[-10%] w-[40%] h-[40%] bg-brand-500/20 rounded-full blur-[120px] animate-pulse" style={{ animationDelay: '1.5s' }}></div>

      <div className="w-full max-w-lg relative z-10">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-brand-500 rounded-2xl shadow-lg shadow-brand-500/30 mb-4 transform hover:scale-110 transition-transform duration-300">
            <HeartPulse className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-white tracking-tight">Join FamilyConnect</h1>
          <p className="text-navy-400 mt-2">Start monitoring your family's health today</p>
        </div>

        <div className="bg-white/10 backdrop-blur-xl border border-white/10 p-8 rounded-[2.5rem] shadow-2xl">
          {error && (
            <div className="mb-6 p-4 bg-red-500/20 border border-red-500/50 rounded-xl text-red-200 text-sm">
              {error}
            </div>
          )}

          <form onSubmit={handleRegister} className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="text-sm font-medium text-navy-200 ml-1">Username</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400">
                  <User className="w-5 h-5" />
                </div>
                <input
                  name="username"
                  required
                  onChange={handleChange}
                  className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
                  placeholder="pravi_dev"
                />
              </div>
            </div>

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
                  onChange={handleChange}
                  className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
                  placeholder="name@example.com"
                />
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-navy-200 ml-1">Role</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400">
                  <ShieldCheck className="w-5 h-5" />
                </div>
                <select
                  name="role"
                  onChange={handleChange}
                  className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white appearance-none focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
                >
                  <option value="MEMBER" className="bg-navy-900">Family Member</option>
                  <option value="HEAD" className="bg-navy-900">Family Head</option>
                </select>
              </div>
            </div>

            <div className="space-y-2 md:col-span-2">
              <label className="text-sm font-medium text-navy-200 ml-1">Password</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400">
                  <Lock className="w-5 h-5" />
                </div>
                <input
                  name="password"
                  type="password"
                  required
                  onChange={handleChange}
                  className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
                  placeholder="••••••••"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full md:col-span-2 bg-brand-500 hover:bg-brand-600 text-white font-bold py-4 rounded-2xl shadow-lg shadow-brand-500/30 transform hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center group mt-4"
            >
              {loading ? (
                <Loader2 className="w-6 h-6 animate-spin" />
              ) : (
                <>
                  Create Account
                  <ArrowRight className="w-5 h-5 ml-2 group-hover:translate-x-1 transition-transform" />
                </>
              )}
            </button>
          </form>

          <div className="mt-8 text-center">
            <p className="text-navy-400 text-sm">
              Already have an account?{' '}
              <Link to="/login" title="Login" className="text-brand-400 font-bold hover:text-brand-300 transition-colors">Sign in</Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
