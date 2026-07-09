import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useEffect } from 'react';
import MainLayout from './layouts/MainLayout';
import Dashboard from './pages/Dashboard';
import HealthHub from './pages/HealthHub';
import FamilyDirectory from './pages/FamilyDirectory';
import Chat from './pages/Chat';
import Emergency from './pages/Emergency';
import Login from './pages/Login';
import Register from './pages/Register';
import OTPVerification from './pages/OTPVerification';
import Settings from './pages/Settings';
import ForgotPassword from './pages/ForgotPassword';
import AISummary from './pages/AISummary';
import HealthComparison from './pages/HealthComparison';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { SyncProvider } from './contexts/SyncContext';

// ── Protected route: waits for auth to load before deciding ─────────────────
const ProtectedRoute = ({ children }) => {
  const { user, loading } = useAuth();

  // While AuthContext is still loading the profile — show nothing (no flash)
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-navy-900">
        <div className="w-8 h-8 border-4 border-brand-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  // No token / user — redirect to login
  if (!user && !localStorage.getItem('access_token')) {
    return <Navigate to="/login" replace />;
  }

  return children;
};

// ── Wake up Render free-tier backend on app load ─────────────────────────────
function ServerWakeUp() {
  useEffect(() => {
    const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
    fetch(`${apiBaseUrl}/api/health/`).catch(() => {});
  }, []);
  return null;
}

function App() {
  return (
    <AuthProvider>
      <SyncProvider>
        <BrowserRouter>
          <ServerWakeUp />
          <Routes>
            {/* Public routes */}
            <Route path="/login"         element={<Login />} />
            <Route path="/register"      element={<Register />} />
            <Route path="/verify-otp"    element={<OTPVerification />} />
            <Route path="/forgot-password" element={<ForgotPassword />} />

            {/* Protected routes — all under MainLayout */}
            <Route
              path="/"
              element={
                <ProtectedRoute>
                  <MainLayout />
                </ProtectedRoute>
              }
            >
              <Route index              element={<Dashboard />} />
              <Route path="health"      element={<HealthHub />} />
              <Route path="family"      element={<FamilyDirectory />} />
              <Route path="chat"        element={<Chat />} />
              <Route path="emergency"   element={<Emergency />} />
              <Route path="settings"    element={<Settings />} />
              <Route path="ai-intelligence"  element={<AISummary />} />
              <Route path="health-comparison" element={<HealthComparison />} />
            </Route>

            {/* Catch-all — redirect unknown paths to dashboard */}
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </BrowserRouter>
      </SyncProvider>
    </AuthProvider>
  );
}

export default App;
