import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { HeartPulse, Mail, ArrowRight, Loader2, Key, CheckCircle } from 'lucide-react';
import api from '../utils/api';

export default function ForgotPassword() {
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [step, setStep] = useState(1); // 1: Request, 2: Confirm
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const navigate = useNavigate();

  const handleRequest = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await api.post('/users/password-reset/', { email });
      setStep(2);
      setMessage('Reset code sent to your email.');
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to send reset code.');
    } finally {
      setLoading(false);
    }
  };

  const handleConfirm = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await api.post('/users/password-reset-confirm/', { 
        email, 
        otp, 
        new_password: newPassword 
      });
      setStep(3); // Success
    } catch (err) {
      setError(err.response?.data?.error || 'Invalid reset code or email.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-navy-900 flex items-center justify-center p-6 relative overflow-hidden">
      {/* Background Blobs */}
      <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-brand-500/20 rounded-full blur-[120px] animate-pulse"></div>
      <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-blue-500/20 rounded-full blur-[120px] animate-pulse" style={{ animationDelay: '1s' }}></div>

      <div className="w-full max-w-md relative z-10">
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-brand-500 rounded-2xl shadow-lg shadow-brand-500/30 mb-4 transform hover:rotate-12 transition-transform duration-300">
            <HeartPulse className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-white tracking-tight">Recover Account</h1>
          <p className="text-navy-400 mt-2">Reset your family health dashboard password</p>
        </div>

        <div className="bg-white/10 backdrop-blur-xl border border-white/10 p-8 rounded-[2rem] shadow-2xl">
          {error && (
            <div className="mb-6 p-4 bg-red-500/20 border border-red-500/50 rounded-xl text-red-200 text-sm">
              {error}
            </div>
          )}

          {step === 1 && (
            <form onSubmit={handleRequest} className="space-y-6">
              <div className="space-y-2">
                <label className="text-sm font-medium text-navy-200 ml-1">Email Address</label>
                <div className="relative group">
                  <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400 transition-colors">
                    <Mail className="w-5 h-5" />
                  </div>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 focus:border-brand-500 transition-all"
                    placeholder="name@example.com"
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full bg-brand-500 hover:bg-brand-600 text-white font-bold py-4 rounded-2xl shadow-lg shadow-brand-500/30 transform hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center group"
              >
                {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : 'Send Reset Code'}
              </button>
            </form>
          )}

          {step === 2 && (
            <form onSubmit={handleConfirm} className="space-y-6">
              <p className="text-sm text-brand-400 font-medium mb-4">{message}</p>
              
              <div className="space-y-2">
                <label className="text-sm font-medium text-navy-200 ml-1">Reset Code</label>
                <div className="relative group">
                  <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-navy-400 group-focus-within:text-brand-400 transition-colors">
                    <Key className="w-5 h-5" />
                  </div>
                  <input
                    type="text"
                    required
                    value={otp}
                    onChange={(e) => setOtp(e.target.value)}
                    className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 pl-12 pr-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 focus:border-brand-500 transition-all text-center tracking-[1em]"
                    placeholder="••••••"
                    maxLength={6}
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-navy-200 ml-1">New Password</label>
                <input
                  type="password"
                  required
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  className="w-full bg-navy-800/50 border border-white/5 rounded-2xl py-3 px-4 text-white placeholder-navy-500 focus:outline-none focus:ring-2 focus:ring-brand-500/50 focus:border-brand-500 transition-all"
                  placeholder="••••••••"
                />
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full bg-brand-500 hover:bg-brand-600 text-white font-bold py-4 rounded-2xl shadow-lg shadow-brand-500/30 transform hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center group"
              >
                {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : 'Reset Password'}
              </button>
            </form>
          )}

          {step === 3 && (
            <div className="text-center py-8">
              <div className="w-20 h-20 bg-emerald-500/20 rounded-full flex items-center justify-center mx-auto mb-6">
                <CheckCircle className="w-10 h-10 text-emerald-500" />
              </div>
              <h2 className="text-2xl font-bold text-white mb-2">Success!</h2>
              <p className="text-navy-400 mb-8">Your password has been reset successfully.</p>
              <Link
                to="/login"
                className="inline-block w-full bg-brand-500 hover:bg-brand-600 text-white font-bold py-4 rounded-2xl shadow-lg shadow-brand-500/30 transition-all"
              >
                Back to Login
              </Link>
            </div>
          )}

          <div className="mt-8 text-center">
            <Link to="/login" className="text-navy-400 text-sm hover:text-brand-400 transition-colors flex items-center justify-center group">
              <ArrowRight className="w-4 h-4 mr-2 rotate-180 group-hover:-translate-x-1 transition-transform" />
              Back to Sign In
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
