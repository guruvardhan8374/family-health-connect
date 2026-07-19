import axios from 'axios';
import OfflineQueue from './offlineQueue';

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

export const clearAuthAndRedirect = (reason = 'session_expired') => {
  ['access_token','refresh_token','user_id','username','email','role','auth_provider']
    .forEach(k => localStorage.removeItem(k));
  // Set a flag so the Login page can show an appropriate message
  if (reason) {
    sessionStorage.setItem('auth_redirect_reason', reason);
  }
  window.location.href = '/login';
};

// ── Attach Bearer token to every outgoing request (except public/auth endpoints) ──
api.interceptors.request.use(
  (config) => {
    const url = config.url || '';
    // Do not send Authorization headers for public endpoints. If an expired/invalid token
    // is sent, Django's JWTAuthentication will fail the request with 401 "Given token not valid",
    // even if the endpoint has AllowAny permission.
    const isPublic = 
      url.includes('/token/') || 
      url.includes('/register/') || 
      url.includes('/verify-otp/') || 
      url.includes('/password-reset/') ||
      url.includes('/verify-phone-otp/') ||
      url.includes('/send-phone-otp/') ||
      url.includes('/health/');

    if (!isPublic) {
      const token = localStorage.getItem('access_token');
      if (token) config.headers.Authorization = `Bearer ${token}`;
    }
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

    // ── Handle offline queueing for failed mutations ──────────────────────────
    if (!error.response && originalRequest) {
      const method = originalRequest.method?.toLowerCase();
      const writeMethods = ['post', 'put', 'patch', 'delete'];
      if (writeMethods.includes(method)) {
        try {
          const payload = originalRequest.data ? JSON.parse(originalRequest.data) : {};
          const endpoint = originalRequest.url.replace(originalRequest.baseURL || '', '');
          
          // Skip public endpoints and refresh token endpoints
          const isPublic = 
            endpoint.includes('/token/') || 
            endpoint.includes('/register/') || 
            endpoint.includes('/verify-otp/') || 
            endpoint.includes('/password-reset/') ||
            endpoint.includes('/verify-phone-otp/') ||
            endpoint.includes('/send-phone-otp/') ||
            endpoint.includes('/health/');

          if (!isPublic) {
            OfflineQueue.push({
              endpoint,
              method: originalRequest.method.toUpperCase(),
              payload,
            });
            console.warn(`[API] Went offline. Enqueued mutation: ${originalRequest.method.toUpperCase()} ${endpoint}`);
            return Promise.resolve({ data: { status: 'queued', offline: true } });
          }
        } catch (e) {
          console.error('[API] Failed to queue offline request:', e);
        }
      }
    }

    // Never try to refresh for Google-auth users — their Firebase tokens
    // expire and must be re-obtained via Google sign-in, not refresh endpoint
    if (localStorage.getItem('auth_provider') === 'google') {
      return Promise.reject(error);
    }

    // Skip the interceptor for public/auth endpoints — a 401 there should be handled
    // directly by the component calling it, not by trying to refresh tokens.
    const url = originalRequest?.url || '';
    const isPublic = 
      url.includes('/token/') || 
      url.includes('/register/') || 
      url.includes('/verify-otp/') || 
      url.includes('/password-reset/') ||
      url.includes('/verify-phone-otp/') ||
      url.includes('/send-phone-otp/') ||
      url.includes('/health/');

    if (isPublic) {
      return Promise.reject(error);
    }

    // Only intercept 401 once per request (prevent infinite retry loops)
    if (status !== 401 || originalRequest._retry) {
      return Promise.reject(error);
    }

    // Detect if the user account was deleted or disabled
    const isHardInvalid = errorCode === 'user_not_found';

    if (isHardInvalid) {
      // User doesn't exist — no point refreshing, force re-login immediately
      isRefreshing = false;
      processQueue(error, null);
      clearAuthAndRedirect('session_expired');
      return Promise.reject(error);
    }

    const refreshToken = localStorage.getItem('refresh_token');

    // No refresh token stored — can't recover, force login
    if (!refreshToken) {
      clearAuthAndRedirect('session_expired');
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
      // ROTATE_REFRESH_TOKENS=True in Django means a new refresh token is issued
      if (res.data.refresh) localStorage.setItem('refresh_token', res.data.refresh);

      api.defaults.headers.common['Authorization'] = `Bearer ${newAccess}`;
      originalRequest.headers.Authorization        = `Bearer ${newAccess}`;

      processQueue(null, newAccess);
      isRefreshing = false;
      // Retry the original request with the new access token
      return api(originalRequest);

    } catch (refreshError) {
      // Refresh failed (refresh token is also expired / revoked) — force re-login
      processQueue(refreshError, null);
      isRefreshing = false;
      clearAuthAndRedirect('session_expired');
      return Promise.reject(refreshError);
    }
  }
);

export default api;
