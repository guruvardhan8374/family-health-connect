import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import api from '../utils/api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  const loadUser = useCallback(async () => {
    const token = localStorage.getItem('access_token');
    if (!token) {
      setLoading(false);
      return;
    }

    // If signed in via Google/Firebase, skip Django API validation
    // and build the user object directly from localStorage
    const authProvider = localStorage.getItem('auth_provider');
    if (authProvider === 'google') {
      setUser({
        username: localStorage.getItem('username') || 'User',
        user_id: localStorage.getItem('user_id'),
        email: localStorage.getItem('username'),
        auth_provider: 'google',
      });
      setLoading(false);
      return;
    }

    // Django JWT users — validate against backend
    try {
      const res = await api.get('/users/profile/');
      setUser(res.data);
    } catch {
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
      localStorage.removeItem('auth_provider');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadUser();
  }, [loadUser]);

  const login = (tokenData) => {
    localStorage.setItem('access_token', tokenData.access);
    localStorage.setItem('refresh_token', tokenData.refresh);
    if (tokenData.user_id) localStorage.setItem('user_id', tokenData.user_id);
    if (tokenData.username) localStorage.setItem('username', tokenData.username);
    loadUser();
  };

  const logout = () => {
    localStorage.clear();
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
