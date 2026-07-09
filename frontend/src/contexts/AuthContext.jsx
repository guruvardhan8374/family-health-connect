import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import api from '../utils/api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser]     = useState(null);
  const [loading, setLoading] = useState(true);

  const loadUser = useCallback(async () => {
    const token = localStorage.getItem('access_token');
    if (!token) {
      setUser(null);
      setLoading(false);
      return;
    }

    // Google / Firebase users — build from localStorage directly
    const authProvider = localStorage.getItem('auth_provider');
    if (authProvider === 'google') {
      setUser({
        id:            localStorage.getItem('user_id'),
        username:      localStorage.getItem('username') || 'User',
        email:         localStorage.getItem('email') || '',
        role:          localStorage.getItem('role') || 'MEMBER',
        auth_provider: 'google',
      });
      setLoading(false);
      return;
    }

    // Django JWT users — fetch full profile from backend
    try {
      const res = await api.get('/users/profile/');
      const profile = res.data;
      // Keep localStorage in sync with latest profile data
      if (profile.id)       localStorage.setItem('user_id',  profile.id.toString());
      if (profile.username) localStorage.setItem('username', profile.username);
      if (profile.email)    localStorage.setItem('email',    profile.email);
      if (profile.role)     localStorage.setItem('role',     profile.role);
      setUser(profile);
    } catch (err) {
      // 401 means token expired/invalid — clear and redirect handled by api interceptor
      if (err.response?.status === 401) {
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        localStorage.removeItem('auth_provider');
        setUser(null);
      }
      // For network errors (Render cold start) keep the cached user from localStorage
      // so the UI doesn't flash logout on slow first load
      else {
        const cachedUser = {
          id:       localStorage.getItem('user_id'),
          username: localStorage.getItem('username') || 'User',
          email:    localStorage.getItem('email') || '',
          role:     localStorage.getItem('role') || 'MEMBER',
        };
        if (cachedUser.id) setUser(cachedUser);
        else setUser(null);
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadUser();
  }, [loadUser]);

  const login = (tokenData) => {
    // Store all tokens and user info
    localStorage.setItem('access_token',  tokenData.access);
    localStorage.setItem('refresh_token', tokenData.refresh);
    if (tokenData.user_id)  localStorage.setItem('user_id',  tokenData.user_id.toString());
    if (tokenData.username) localStorage.setItem('username', tokenData.username);
    if (tokenData.email)    localStorage.setItem('email',    tokenData.email);
    if (tokenData.role)     localStorage.setItem('role',     tokenData.role);
    // Then fetch full profile so user object has all fields
    loadUser();
  };

  const logout = () => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('user_id');
    localStorage.removeItem('username');
    localStorage.removeItem('email');
    localStorage.removeItem('role');
    localStorage.removeItem('auth_provider');
    setUser(null);
    window.location.href = '/login';
  };

  const refreshUser = () => loadUser();

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
