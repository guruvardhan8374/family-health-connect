import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import api from '../utils/api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user,    setUser]    = useState(null);
  const [loading, setLoading] = useState(true);

  // ── Load / refresh the user profile from backend ────────────────────────
  const loadUser = useCallback(async () => {
    const token = localStorage.getItem('access_token');
    if (!token) {
      setUser(null);
      setLoading(false);
      return;
    }

    // Google/Firebase — reconstruct user from localStorage (no backend call needed)
    if (localStorage.getItem('auth_provider') === 'google') {
      setUser({
        id:            localStorage.getItem('user_id'),
        username:      localStorage.getItem('username') || 'User',
        email:         localStorage.getItem('email')    || '',
        role:          localStorage.getItem('role')     || 'MEMBER',
        auth_provider: 'google',
      });
      setLoading(false);
      return;
    }

    // Django JWT — fetch full profile
    try {
      const res     = await api.get('/users/profile/');
      const profile = res.data;
      // Keep localStorage in sync
      if (profile.id)       localStorage.setItem('user_id',  profile.id.toString());
      if (profile.username) localStorage.setItem('username', profile.username);
      if (profile.email)    localStorage.setItem('email',    profile.email);
      if (profile.role)     localStorage.setItem('role',     profile.role);
      setUser(profile);
    } catch (err) {
      if (err.response?.status === 401) {
        // Token invalid — the api.js interceptor will already have:
        // 1. Tried to refresh the token (if refresh token exists)
        // 2. Either retried and succeeded (in which case this catch won't run)
        //    OR called clearAuthAndRedirect (which navigates away)
        // We only land here if the interceptor re-threw the error after redirect.
        // Safely set user to null without double-redirecting.
        setUser(null);
      } else {
        // Network error (Render cold start) — serve cached user so UI doesn't flash logout
        const cached = {
          id:       localStorage.getItem('user_id'),
          username: localStorage.getItem('username') || 'User',
          email:    localStorage.getItem('email')    || '',
          role:     localStorage.getItem('role')     || 'MEMBER',
        };
        setUser(cached.id ? cached : null);
      }
    } finally {
      setLoading(false);
    }
  }, []);

  // Load user on mount
  useEffect(() => { loadUser(); }, [loadUser]);

  // ── Called immediately after a successful login API response ─────────────
  // Returns a Promise so callers can await it before navigating
  const login = useCallback((tokenData) => {
    // Store tokens FIRST — synchronously — before any async calls
    localStorage.setItem('access_token',  tokenData.access);
    localStorage.setItem('refresh_token', tokenData.refresh);
    if (tokenData.user_id)  localStorage.setItem('user_id',  tokenData.user_id.toString());
    if (tokenData.username) localStorage.setItem('username', tokenData.username);
    if (tokenData.email)    localStorage.setItem('email',    tokenData.email);
    if (tokenData.role)     localStorage.setItem('role',     tokenData.role);
    // Clear any stale session-expired flag from a prior logout
    sessionStorage.removeItem('auth_redirect_reason');
    return loadUser(); // returns the promise — callers can await
  }, [loadUser]);

  // ── Full logout ──────────────────────────────────────────────────────────
  const logout = useCallback(() => {
    ['access_token','refresh_token','user_id','username','email','role','auth_provider']
      .forEach(k => localStorage.removeItem(k));
    setUser(null);
    window.location.href = '/login';
  }, []);

  const refreshUser = useCallback(() => loadUser(), [loadUser]);

  return (
    <AuthContext.Provider value={{ user, loading, login, logout, refreshUser }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
};
