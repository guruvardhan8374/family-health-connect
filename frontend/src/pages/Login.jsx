import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { HeartPulse, Mail, Lock, ArrowRight, Loader2, Fingerprint } from 'lucide-react';
import api from '../utils/api';
import { signInWithGoogle } from '../utils/firebase';
import { useAuth } from '../contexts/AuthContext';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const navigate = useNavigate();
  const { login } = useAuth();

  const handleGoogleLogin = async () => {
    try {
      const user = await signInWithGoogle();
      console.log("Google User:", user);
      // In a real app, send the user's ID token to your backend
      // to create/login the user and get a JWT.
      navigate('/');
    } catch (err) {
      setError('Google Sign-In failed.');
    }
  };

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      console.log("Attempting login for:", email);
      const response = await api.post('/token/', {
      username: email.trim(),
      password: password.trim(),
      });
      
      const userData = {
        access: response.data.access,
        refresh: response.data.refresh,
        username: email.split('@')[0],
        user_id: response.data.user_id || '1'
      };
      
      login(userData);
      console.log("Login successful");
      navigate('/');
    } catch (err) {
      console.error("Login Error Details:", {
        message: err.message,
        response: err.response?.data,
        status: err.response?.status,
        url: err.config?.url
      });
      if (!err.response) {
        // Find the API base URL being used
        const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
        setError(`Cannot connect to server. Please ensure the Django backend is running at ${apiBaseUrl}`);
      } else {
        setError('Invalid username or password. Please check your credentials.');
      }
    } finally {
      setLoading(false);
    }
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
              className="w-full bg-white/5 hover:bg-white/10 border border-white/10 text-white font-bold py-4 rounded-2xl transition-all flex items-center justify-center space-x-3 group"
            >
              <img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/action/google.svg" className="w-5 h-5" alt="Google" />
              <span>Sign in with Google</span>
            </button>
          </form>

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
