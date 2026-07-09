import axios from 'axios';

const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';

const api = axios.create({
  baseURL: `${apiBaseUrl}/api/v1`,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 60000, // 60s — handles Render cold start wakeup
});

let isRefreshing = false;
let failedQueue = [];

const processQueue = (error, token = null) => {
  failedQueue.forEach((prom) => {
    if (error) prom.reject(error);
    else prom.resolve(token);
  });
  failedQueue = [];
};

const clearAuthAndRedirect = () => {
  localStorage.removeItem('access_token');
  localStorage.removeItem('refresh_token');
  localStorage.removeItem('user_id');
  localStorage.removeItem('username');
  localStorage.removeItem('email');
  localStorage.removeItem('role');
  localStorage.removeItem('auth_provider');
  window.location.href = '/login';
};

// Attach access token to every request
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('access_token');
    if (token) config.headers.Authorization = `Bearer ${token}`;
    return config;
  },
  (error) => Promise.reject(error)
);

// Handle 401 — try refresh, then redirect to login
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    const status = error.response?.status;
    const errorCode = error.response?.data?.code;
    const errorDetail = error.response?.data?.detail || '';

    // Google users — don't try to refresh Django tokens
    if (localStorage.getItem('auth_provider') === 'google') {
      return Promise.reject(error);
    }

    // Token is completely invalid (not just expired) — clear and redirect immediately
    // This covers: token_not_valid, user_not_found, token_type_claim_invalid
    const isTokenInvalid =
      errorCode === 'token_not_valid' ||
      errorCode === 'user_not_found' ||
      errorDetail.includes('token_not_valid') ||
      errorDetail.includes('not valid');

    if (status === 401 && isTokenInvalid && !originalRequest._retry) {
      // Try refresh first — maybe only access token is bad
      const refreshToken = localStorage.getItem('refresh_token');
      if (!refreshToken) {
        clearAuthAndRedirect();
        return Promise.reject(error);
      }

      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        })
          .then((token) => {
            originalRequest.headers.Authorization = `Bearer ${token}`;
            return api(originalRequest);
          })
          .catch((err) => Promise.reject(err));
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const response = await axios.post(
          `${apiBaseUrl}/api/token/refresh/`,
          { refresh: refreshToken },
          { timeout: 60000 }
        );
        const newAccessToken = response.data.access;
        localStorage.setItem('access_token', newAccessToken);
        if (response.data.refresh) {
          localStorage.setItem('refresh_token', response.data.refresh);
        }
        api.defaults.headers.common['Authorization'] = `Bearer ${newAccessToken}`;
        originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
        processQueue(null, newAccessToken);
        isRefreshing = false;
        return api(originalRequest);
      } catch (refreshError) {
        // Refresh also failed — session is fully expired, force re-login
        processQueue(refreshError, null);
        isRefreshing = false;
        clearAuthAndRedirect();
        return Promise.reject(refreshError);
      }
    }

    // Generic 401 (no code) — same refresh flow
    if (status === 401 && !originalRequest._retry && !isTokenInvalid) {
      const refreshToken = localStorage.getItem('refresh_token');
      if (!refreshToken) {
        clearAuthAndRedirect();
        return Promise.reject(error);
      }

      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        })
          .then((token) => {
            originalRequest.headers.Authorization = `Bearer ${token}`;
            return api(originalRequest);
          })
          .catch((err) => Promise.reject(err));
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const response = await axios.post(
          `${apiBaseUrl}/api/token/refresh/`,
          { refresh: refreshToken },
          { timeout: 60000 }
        );
        const newAccessToken = response.data.access;
        localStorage.setItem('access_token', newAccessToken);
        if (response.data.refresh) {
          localStorage.setItem('refresh_token', response.data.refresh);
        }
        api.defaults.headers.common['Authorization'] = `Bearer ${newAccessToken}`;
        originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
        processQueue(null, newAccessToken);
        isRefreshing = false;
        return api(originalRequest);
      } catch (refreshError) {
        processQueue(refreshError, null);
        isRefreshing = false;
        clearAuthAndRedirect();
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);

export default api;
