import axios from 'axios';

const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';

const api = axios.create({
  baseURL: `${apiBaseUrl}/api/v1`,
  headers: { 'Content-Type': 'application/json' },
  timeout: 60000, // 60s — handles Render cold start wakeup
});

let isRefreshing = false;
let failedQueue  = [];

const processQueue = (error, token = null) => {
  failedQueue.forEach(p => error ? p.reject(error) : p.resolve(token));
  failedQueue = [];
};

export const clearAuthAndRedirect = () => {
  ['access_token','refresh_token','user_id','username','email','role','auth_provider']
    .forEach(k => localStorage.removeItem(k));
  window.location.href = '/login';
};

// ── Attach Bearer token to every outgoing request ──────────────────────────
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('access_token');
    if (token) config.headers.Authorization = `Bearer ${token}`;
    return config;
  },
  (error) => Promise.reject(error)
);

// ── Handle 401: try silent token refresh, then force re-login ──────────────
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    const status      = error.response?.status;
    const errorCode   = error.response?.data?.code   || '';
    const errorDetail = error.response?.data?.detail || '';

    // Never try to refresh for Google-auth users
    if (localStorage.getItem('auth_provider') === 'google') {
      return Promise.reject(error);
    }

    // Only intercept 401 once per request
    if (status !== 401 || originalRequest._retry) {
      return Promise.reject(error);
    }

    // Detect completely invalid tokens (bad signature, wrong type, etc.)
    const isHardInvalid =
      errorCode   === 'token_not_valid'  ||
      errorCode   === 'user_not_found'   ||
      errorDetail.includes('token_not_valid') ||
      errorDetail.includes('not valid');

    const refreshToken = localStorage.getItem('refresh_token');

    // No refresh token stored — can't recover, force login
    if (!refreshToken) {
      clearAuthAndRedirect();
      return Promise.reject(error);
    }

    // Another refresh already in-flight — queue this request
    if (isRefreshing) {
      return new Promise((resolve, reject) => {
        failedQueue.push({ resolve, reject });
      }).then(token => {
        originalRequest.headers.Authorization = `Bearer ${token}`;
        return api(originalRequest);
      }).catch(err => Promise.reject(err));
    }

    originalRequest._retry = true;
    isRefreshing = true;

    try {
      const res = await axios.post(
        `${apiBaseUrl}/api/token/refresh/`,
        { refresh: refreshToken },
        { timeout: 60000 }
      );
      const newAccess = res.data.access;
      localStorage.setItem('access_token', newAccess);
      if (res.data.refresh) localStorage.setItem('refresh_token', res.data.refresh);

      api.defaults.headers.common['Authorization'] = `Bearer ${newAccess}`;
      originalRequest.headers.Authorization        = `Bearer ${newAccess}`;

      processQueue(null, newAccess);
      isRefreshing = false;
      return api(originalRequest);

    } catch (refreshError) {
      // Refresh failed (token truly expired / revoked) — force re-login
      processQueue(refreshError, null);
      isRefreshing = false;
      clearAuthAndRedirect();
      return Promise.reject(refreshError);
    }
  }
);

export default api;
