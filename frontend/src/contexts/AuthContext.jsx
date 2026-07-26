import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import api from '../utils/api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user,    setUser]    = useState(null);
  const [loading, setLoading] = useState(true);

  // ── Load / refresh the user profile & family state from backend ───────────
  const loadUser = useCallback(async () => {
    const token = localStorage.getItem('access_token');
    if (!token) {
      setUser(null);
      setLoading(false);
      return;
    }

    try {
      const res     = await api.get('/users/profile/');
      const profile = res.data;
      // Keep localStorage in sync
      if (profile.id)           localStorage.setItem('user_id',  profile.id.toString());
      if (profile.username)     localStorage.setItem('username', profile.username);
      if (profile.email)        localStorage.setItem('email',    profile.email);
      if (profile.role)         localStorage.setItem('role',     profile.role);
      if (profile.has_family)   localStorage.setItem('has_family', 'true');
      else                      localStorage.removeItem('has_family');

      setUser(profile);
    } catch (err) {
      if (err.response?.status === 401) {
        setUser(null);
      } else {
        const cached = {
          id:          localStorage.getItem('user_id'),
          username:    localStorage.getItem('username') || 'User',
          email:       localStorage.getItem('email')    || '',
          role:        localStorage.getItem('role')     || 'MEMBER',
          has_family:  localStorage.getItem('has_family') === 'true',
        };
        setUser(cached.id ? cached : null);
      }
    } finally {
      setLoading(false);
    }
  }, []);

  // Load user on mount
  useEffect(() => {
    let active = true;
    Promise.resolve().then(() => {
      if (active) {
        loadUser();
      }
    });
    return () => { active = false; };
  }, [loadUser]);

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
