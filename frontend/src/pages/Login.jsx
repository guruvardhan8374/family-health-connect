import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { HeartPulse, Mail, Lock, ArrowRight, Loader2, Fingerprint, Phone, ShieldCheck } from 'lucide-react';
import api from '../utils/api';
import { signInWithGoogle } from '../utils/firebase';
import { useAuth } from '../contexts/AuthContext';

export default function Login() {
  // --- Tab state ---
  const [activeTab, setActiveTab] = useState('phone'); // 'password' | 'phone'

  // --- Password login state ---
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [error, setError] = useState('');

  // --- Phone OTP state ---
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [otpStep, setOtpStep] = useState('phone'); // 'phone' | 'otp'
  const [phoneLoading, setPhoneLoading] = useState(false);
  const [phoneError, setPhoneError] = useState('');
  const [phoneSuccess, setPhoneSuccess] = useState('');
  const [resendTimer, setResendTimer] = useState(0);

  const navigate = useNavigate();
  const { login } = useAuth();

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

  // ─────────────────────── Password Login ───────────────────────
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
        username: email.split('@')[0],
        user_id: response.data.user_id || '1',
      };
      login(userData);
      navigate('/');
    } catch (err) {
      if (!err.response) {
        const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
        setError(`Cannot connect to server at ${apiBaseUrl}`);
      } else {
        setError('Invalid username or password. Please check your credentials.');
      }
    } finally {
      setLoading(false);
    }
  };

  // ─────────────────────── Phone OTP ───────────────────────
  // Effect for timer
  useEffect(() => {
    // Timer countdown logic
    let interval;
    if (resendTimer > 0) {
      interval = setInterval(() => {
        setResendTimer((prev) => prev - 1);
      }, 1000);
    } else if (resendTimer === 0) {
      clearInterval(interval);
    }
    return () => clearInterval(interval);
  }, [resendTimer]);

  const handleSendOTP = async (e) => {
    if (e) e.preventDefault();
    if (!phone || phone.length < 10) {
      setPhoneError('Please enter a valid phone number (e.g. +919876543210)');
      return;
    }

    setPhoneLoading(true);
    setPhoneError('');
    setPhoneSuccess('');
    
    try {
      await api.post('/users/send-phone-otp/', { phone_number: phone.trim() });
      setPhoneSuccess('OTP sent successfully!');
      setOtpStep('otp');
      setResendTimer(30); // 30 second cooldown for resend
    } catch (err) {
      setPhoneError(err.response?.data?.error || 'Failed to send OTP. Please try again.');
    } finally {
      setPhoneLoading(false);
    }
  };

  const handleVerifyOTP = async (e) => {
    e.preventDefault();

    setPhoneLoading(true);
    setPhoneError('');
    try {
      const response = await api.post('/users/verify-phone-otp/', {
        phone_number: phone.trim(),
        otp: otp.trim(),
      });
      const userData = {
        access: response.data.access,
        refresh: response.data.refresh,
        username: response.data.username || `user_${phone.slice(-4)}`,
        user_id: response.data.user_id?.toString() || '1',
      };
      
      login(userData);
      navigate('/');
    } catch (err) {
      setPhoneError(err.response?.data?.error || 'Invalid or expired OTP. Please try again.');
    } finally {
      setPhoneLoading(false);
    }
  };

  const resetPhoneFlow = () => {
    setOtpStep('phone');
    setOtp('');
    setPhoneError('');
    setPhoneSuccess('');
  };

  return (
    <div className="min-h-screen bg-navy-900 flex flex-col md:items-center md:justify-center p-4 md:p-6 relative overflow-hidden">
      {/* Background Blobs */}
      <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-brand-500/20 rounded-full blur-[120px] animate-pulse"></div>
      <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-blue-500/20 rounded-full blur-[120px] animate-pulse" style={{ animationDelay: '1s' }}></div>

      <div className="w-full max-w-md relative z-10">
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-brand-500 rounded-2xl shadow-lg shadow-brand-500/30 mb-4 transform hover:rotate-12 transition-transform duration-300">
            <HeartPulse className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-white tracking-tight">Welcome Back</h1>
          <p className="text-navy-400 mt-2">Sign in to your family health dashboard</p>
        </div>

        <div className="bg-white/10 backdrop-blur-xl border border-white/10 p-8 rounded-[2rem] shadow-2xl">

          {/* ── Tab Switcher ── */}
          <div className="flex bg-navy-800/60 rounded-2xl p-1 mb-7 gap-1">
            <button
              onClick={() => { setActiveTab('password'); setError(''); }}
              className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-semibold transition-all ${
                activeTab === 'password'
                  ? 'bg-brand-500 text-white shadow-lg shadow-brand-500/30'
                  : 'text-navy-400 hover:text-white'
              }`}
            >
              <Mail className="w-4 h-4" />
              Email / Password
            </button>
            <button
              onClick={() => { setActiveTab('phone'); setPhoneError(''); setPhoneSuccess(''); }}
              className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-semibold transition-all ${
                activeTab === 'phone'
                  ? 'bg-brand-500 text-white shadow-lg shadow-brand-500/30'
                  : 'text-navy-400 hover:text-white'
              }`}
            >
              <Phone className="w-4 h-4" />
              Phone OTP
            </button>
          </div>

          {/* ══════════ PASSWORD TAB ══════════ */}
          {activeTab === 'password' && (
            <>
              {error && (
                <div className="mb-6 p-4 bg-red-500/20 border border-red-500/50 rounded-xl text-red-200 text-sm">
                  {error}
                </div>
              )}

              <form onSubmit={handleLogin} className="space-y-6">
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
                      className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 focus:border-brand-500 transition-all"
                      placeholder="testuser or name@example.com"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <div className="flex justify-between items-center ml-1">
                    <label className="text-sm font-medium text-navy-200">Password</label>
                    <Link to="/forgot-password" title="Forgot Password" className="text-xs text-brand-400 hover:text-brand-300 transition-colors">Forgot password?</Link>
                  </div>
                  <div className="relative group">
                    <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400 transition-colors">
                      <Lock className="w-5 h-5" />
                    </div>
                    <input
                      id="login-password"
                      type="password"
                      required
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 focus:border-brand-500 transition-all"
                      placeholder="••••••••"
                    />
                  </div>
                </div>

                <div className="flex items-center space-x-4">
                  <button
                    type="submit"
                    id="login-submit"
                    disabled={loading}
                    className="flex-1 bg-brand-500 hover:bg-brand-600 text-white font-bold py-4 rounded-2xl shadow-lg shadow-brand-500/30 transform hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center group"
                  >
                    {loading ? (
                      <Loader2 className="w-6 h-6 animate-spin" />
                    ) : (
                      <>
                        Sign In
                        <ArrowRight className="w-5 h-5 ml-2 group-hover:translate-x-1 transition-transform" />
                      </>
                    )}
                  </button>
                  
                  <button
                    type="button"
                    onClick={() => alert('Biometric authentication is only available on secure HTTPS connections with supported hardware.')}
                    className="p-4 bg-white/5 hover:bg-white/10 border border-white/10 rounded-2xl text-brand-400 transition-all hover:scale-105"
                    title="Sign in with Biometrics"
                  >
                    <Fingerprint className="w-6 h-6" />
                  </button>
                </div>

                <div className="relative my-8">
                  <div className="absolute inset-0 flex items-center">
                    <div className="w-full border-t border-white/10"></div>
                  </div>
                  <div className="relative flex justify-center text-xs uppercase">
                    <span className="bg-navy-900 px-2 text-navy-500 font-bold tracking-widest">Or continue with</span>
                  </div>
                </div>

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
            </>
          )}

          {/* ══════════ PHONE OTP TAB ══════════ */}
          {activeTab === 'phone' && (
            <div className="space-y-6">
              {phoneError && (
                <div className="p-4 bg-red-500/20 border border-red-500/50 rounded-xl text-red-200 text-sm">
                  {phoneError}
                </div>
              )}
              {phoneSuccess && (
                <div className="p-4 bg-green-500/20 border border-green-500/50 rounded-xl text-green-200 text-sm">
                  {phoneSuccess}
                </div>
              )}

              {otpStep === 'phone' ? (
                /* ── Step 1: Enter Phone Number ── */
                <form onSubmit={handleSendOTP} className="space-y-5">
                  <div className="text-center pb-2">
                    <div className="inline-flex items-center justify-center w-14 h-14 bg-brand-500/20 rounded-2xl mb-3">
                      <Phone className="w-7 h-7 text-brand-400" />
                    </div>
                    <p className="text-navy-300 text-sm">Enter your phone number and we'll send a one-time code to verify your identity.</p>
                  </div>
                  <div className="space-y-2">
                    <label className="text-sm font-medium text-navy-200 ml-1">Phone Number</label>
                    <div className="relative group">
                      <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400 transition-colors">
                        <Phone className="w-5 h-5" />
                      </div>
                      <input
                        id="phone-input"
                        type="tel"
                        required
                        value={phone}
                        onChange={(e) => setPhone(e.target.value)}
                        className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 focus:border-brand-500 transition-all"
                        placeholder="+91 9876543210"
                      />
                    </div>
                  </div>
                  <button
                    type="submit"
                    id="send-otp-btn"
                    disabled={phoneLoading}
                    className="w-full bg-brand-500 hover:bg-brand-600 text-white font-bold py-4 rounded-2xl shadow-lg shadow-brand-500/30 transform hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center gap-2"
                  >
                    {phoneLoading ? <Loader2 className="w-5 h-5 animate-spin" /> : (
                      <>Send OTP <ArrowRight className="w-5 h-5" /></>
                    )}
                  </button>
                </form>
              ) : (
                /* ── Step 2: Enter OTP ── */
                <form onSubmit={handleVerifyOTP} className="space-y-5">
                  <div className="text-center pb-2">
                    <div className="inline-flex items-center justify-center w-14 h-14 bg-brand-500/20 rounded-2xl mb-3">
                      <ShieldCheck className="w-7 h-7 text-brand-400" />
                    </div>
                    <p className="text-navy-300 text-sm">Enter the 6-digit code sent to <span className="text-white font-semibold">{phone}</span></p>
                  </div>
                  <div className="space-y-2">
                    <label className="text-sm font-medium text-navy-200 ml-1">Verification Code</label>
                    <input
                      id="otp-input"
                      type="text"
                      required
                      maxLength={6}
                      value={otp}
                      onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                      className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 px-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 focus:border-brand-500 transition-all text-center text-2xl tracking-[0.5em] font-mono"
                      placeholder="______"
                    />
                  </div>
                  <button
                    type="submit"
                    id="verify-otp-btn"
                    disabled={phoneLoading || otp.length < 6}
                    className="w-full bg-brand-500 hover:bg-brand-600 text-white font-bold py-4 rounded-2xl shadow-lg shadow-brand-500/30 transform hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {phoneLoading ? <Loader2 className="w-5 h-5 animate-spin" /> : (
                      <>Verify &amp; Sign In <ArrowRight className="w-5 h-5" /></>
                    )}
                  </button>
                  <div className="flex justify-between items-center w-full mt-4">
                    <button
                      type="button"
                      onClick={resetPhoneFlow}
                      className="text-navy-400 hover:text-white text-sm transition-colors py-1"
                    >
                      ← Different number
                    </button>
                    
                    <button
                      type="button"
                      onClick={handleSendOTP}
                      disabled={resendTimer > 0 || phoneLoading}
                      className={`text-sm py-1 font-medium transition-colors ${
                        resendTimer > 0 ? 'text-navy-500 cursor-not-allowed' : 'text-brand-400 hover:text-brand-300'
                      }`}
                    >
                      {resendTimer > 0 ? `Resend code in ${resendTimer}s` : 'Resend OTP'}
                    </button>
                  </div>
                </form>
              )}
            </div>
          )}

          <div className="mt-8 text-center">
            <p className="text-navy-400 text-sm">
              Don't have an account?{' '}
              <Link to="/register" title="Register" className="text-brand-400 font-bold hover:text-brand-300 transition-colors">Create account</Link>
            </p>
          </div>
        </div>

        <div className="mt-8 flex justify-center space-x-6 text-navy-500 text-xs font-medium uppercase tracking-widest">
          <span className="hover:text-navy-300 cursor-pointer transition-colors">Privacy Policy</span>
          <span>•</span>
          <span className="hover:text-navy-300 cursor-pointer transition-colors">Terms of Service</span>
        </div>
      </div>
    </div>
  );
}
