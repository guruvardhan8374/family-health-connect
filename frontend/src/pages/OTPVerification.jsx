import { useState, useRef, useEffect, useCallback } from 'react';
import { useNavigate, useLocation, useSearchParams } from 'react-router-dom';
import { ShieldCheck, ArrowRight, Loader2, RefreshCw, Mail } from 'lucide-react';
import api from '../utils/api';

const OTP_LENGTH = 6;
const RESEND_COOLDOWN = 60; // seconds

export default function OTPVerification() {
  const [otp, setOtp]           = useState(Array(OTP_LENGTH).fill(''));
  const [loading, setLoading]   = useState(false);
  const [resending, setResending] = useState(false);
  const [error, setError]       = useState('');
  const [success, setSuccess]   = useState('');
  const [countdown, setCountdown] = useState(0);

  const inputRefs = useRef([]);
  const navigate  = useNavigate();
  const location  = useLocation();
  const [searchParams] = useSearchParams();
  // Support email from router state (navigate with state) OR query param (?email=...)
  const email = location.state?.email || searchParams.get('email') || '';

  const focusInput = (index) => {
    if (index >= 0 && index < OTP_LENGTH) {
      inputRefs.current[index]?.focus();
    }
  };

  const startCountdown = useCallback(() => {
    setCountdown(RESEND_COOLDOWN);
    const interval = setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) { clearInterval(interval); return 0; }
        return prev - 1;
      });
    }, 1000);
  }, []);

  const handleVerify = useCallback(async (e) => {
    if (e) e.preventDefault();
    const otpValue = otp.join('');
    if (otpValue.length < OTP_LENGTH) {
      setError('Please enter all 6 digits.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      await api.post('/users/verify-otp/', { email, otp: otpValue });
      setSuccess('Account verified! Redirecting to login...');
      setTimeout(() => navigate('/login', { state: { verified: true } }), 1500);
    } catch (err) {
      const msg = err.response?.data?.error || err.response?.data?.detail || 'Invalid OTP. Please check and try again.';
      setError(msg);
      // Clear inputs on wrong OTP so user can retype
      setOtp(Array(OTP_LENGTH).fill(''));
      focusInput(0);
    } finally {
      setLoading(false);
    }
  }, [otp, email, navigate]);

  // Start resend countdown on mount
  useEffect(() => {
    startCountdown();
  }, [startCountdown]);

  // Auto-submit when all 6 digits filled
  useEffect(() => {
    if (otp.every(d => d !== '')) {
      handleVerify();
    }
  }, [otp, handleVerify]);

  const handleChange = (e, index) => {
    const val = e.target.value.replace(/\D/g, ''); // digits only
    if (!val) return;
    const newOtp = [...otp];
    newOtp[index] = val.slice(-1); // take last digit if user types fast
    setOtp(newOtp);
    setError('');
    if (index < OTP_LENGTH - 1) focusInput(index + 1);
  };

  const handleKeyDown = (e, index) => {
    if (e.key === 'Backspace') {
      e.preventDefault();
      const newOtp = [...otp];
      if (otp[index]) {
        // Clear current
        newOtp[index] = '';
        setOtp(newOtp);
      } else {
        // Move back and clear previous
        newOtp[Math.max(0, index - 1)] = '';
        setOtp(newOtp);
        focusInput(index - 1);
      }
    } else if (e.key === 'ArrowLeft') {
      focusInput(index - 1);
    } else if (e.key === 'ArrowRight') {
      focusInput(index + 1);
    }
  };

  // Handle paste — e.g. user pastes "123456"
  const handlePaste = (e) => {
    e.preventDefault();
    const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, OTP_LENGTH);
    if (!pasted) return;
    const newOtp = Array(OTP_LENGTH).fill('');
    pasted.split('').forEach((char, i) => { newOtp[i] = char; });
    setOtp(newOtp);
    setError('');
    focusInput(Math.min(pasted.length, OTP_LENGTH - 1));
  };

  const handleResend = async () => {
    if (countdown > 0 || !email) return;
    setResending(true);
    setError('');
    setSuccess('');
    try {
      const res = await api.post('/users/resend-otp/', { email });
      const code = res.data?.otp;
      setSuccess(code ? `New verification code generated: ${code}` : 'A new OTP has been sent to your email.');
      setOtp(Array(OTP_LENGTH).fill(''));
      focusInput(0);
      startCountdown();
    } catch (err) {
      setError('Failed to resend OTP. Please try again.');
    } finally {
      setResending(false);
    }
  };

  return (
    <div className="min-h-screen bg-navy-900 flex items-center justify-center p-6 relative overflow-hidden">
      <div className="absolute top-[10%] left-[10%] w-[40%] h-[40%] bg-brand-500/10 rounded-full blur-[120px]"></div>
      <div className="absolute bottom-[10%] right-[10%] w-[30%] h-[30%] bg-blue-500/10 rounded-full blur-[100px]"></div>

      <div className="w-full max-w-md relative z-10">
        {/* Header */}
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-brand-500 rounded-2xl shadow-lg shadow-brand-500/30 mb-4">
            <ShieldCheck className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-white tracking-tight">Verify Your Account</h1>
          <p className="text-navy-400 mt-2">
            We sent a 6-digit code to
          </p>
          {email && (
            <div className="inline-flex items-center space-x-2 mt-2 bg-white/10 rounded-xl px-4 py-2">
              <Mail className="w-4 h-4 text-brand-400" />
              <span className="text-brand-300 font-semibold text-sm">{email}</span>
            </div>
          )}
        </div>

        <div className="bg-white/10 backdrop-blur-xl border border-white/10 p-8 rounded-[2rem] shadow-2xl">

          {/* Error */}
          {error && (
            <div className="mb-6 p-4 bg-red-500/20 border border-red-500/50 rounded-xl text-red-200 text-sm">
              {error}
            </div>
          )}

          {/* Success */}
          {success && (
            <div className="mb-6 p-4 bg-emerald-500/20 border border-emerald-500/50 rounded-xl text-emerald-200 text-sm flex items-center space-x-2">
              <ShieldCheck className="w-4 h-4 shrink-0" />
              <span>{success}</span>
            </div>
          )}

          <form onSubmit={handleVerify} className="space-y-8">
            {/* OTP inputs */}
            <div className="flex justify-between gap-2" onPaste={handlePaste}>
              {otp.map((digit, index) => (
                <input
                  key={index}
                  ref={el => inputRefs.current[index] = el}
                  type="text"
                  inputMode="numeric"
                  maxLength="1"
                  value={digit}
                  onChange={(e) => handleChange(e, index)}
                  onKeyDown={(e) => handleKeyDown(e, index)}
                  onFocus={(e) => e.target.select()}
                  className={`w-12 h-14 rounded-2xl text-center text-2xl font-bold transition-all outline-none
                    ${digit
                      ? 'bg-brand-500/20 border-2 border-brand-500 text-white'
                      : 'bg-navy-800/50 border border-white/10 text-white'
                    }
                    focus:border-brand-500 focus:ring-2 focus:ring-brand-500/40`}
                />
              ))}
            </div>

            <p className="text-center text-navy-500 text-xs">
              Tip: You can paste the full 6-digit code directly
            </p>

            {/* Verify button */}
            <button
              type="submit"
              disabled={loading || otp.join('').length < OTP_LENGTH}
              className="w-full bg-brand-500 hover:bg-brand-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold py-4 rounded-2xl shadow-lg shadow-brand-500/30 transform hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center justify-center group"
            >
              {loading ? (
                <><Loader2 className="w-5 h-5 animate-spin mr-2" /><span>Verifying...</span></>
              ) : (
                <>Verify OTP<ArrowRight className="w-5 h-5 ml-2 group-hover:translate-x-1 transition-transform" /></>
              )}
            </button>
          </form>

          {/* Resend section */}
          <div className="mt-6 text-center">
            {countdown > 0 ? (
              <p className="text-navy-400 text-sm">
                Resend code in <span className="text-brand-400 font-bold">{countdown}s</span>
              </p>
            ) : (
              <button
                onClick={handleResend}
                disabled={resending}
                className="inline-flex items-center space-x-2 text-brand-400 hover:text-brand-300 font-bold text-sm transition-colors disabled:opacity-50"
              >
                {resending
                  ? <><Loader2 className="w-4 h-4 animate-spin" /><span>Sending...</span></>
                  : <><RefreshCw className="w-4 h-4" /><span>Resend Code</span></>
                }
              </button>
            )}
          </div>

          <div className="mt-4 text-center">
            <button
              onClick={() => navigate('/login')}
              className="text-navy-500 hover:text-navy-300 text-xs transition-colors"
            >
              ← Back to Login
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
