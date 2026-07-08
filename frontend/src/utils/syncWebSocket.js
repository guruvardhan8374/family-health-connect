/**
 * syncWebSocket.js
 * ─────────────────
 * Singleton WebSocket manager for the real-time sync channel.
 *
 * Usage (inside SyncContext):
 *   import SyncWS from './syncWebSocket';
 *   SyncWS.connect(token, onMessage);
 *   SyncWS.disconnect();
 */

const WS_BASE = (() => {
  const apiUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
  // Convert http(s) → ws(s)
  return apiUrl.replace(/^http/, 'ws');
})();

const MAX_RETRIES = 10;
const BASE_DELAY_MS = 1000;

class SyncWebSocket {
  constructor() {
    this._ws = null;
    this._token = null;
    this._onMessage = null;
    this._retries = 0;
    this._retryTimer = null;
    this._manualClose = false;
  }

  /**
   * Open (or reopen) the WebSocket connection.
   * @param {string} token  - JWT access token
   * @param {Function} onMessage - callback(parsedEvent)
   */
  connect(token, onMessage) {
    this._token = token;
    this._onMessage = onMessage;
    this._manualClose = false;
    this._retries = 0;
    this._open();
  }

  /** Update the JWT (called on token refresh). */
  updateToken(token) {
    this._token = token;
    // Reconnect so the new token takes effect
    if (this._ws) {
      this._ws.close();
    }
  }

  disconnect() {
    this._manualClose = true;
    clearTimeout(this._retryTimer);
    if (this._ws) {
      this._ws.close();
      this._ws = null;
    }
  }

  _open() {
    if (!this._token) return;

    const url = `${WS_BASE}/ws/sync/?token=${this._token}`;
    this._ws = new WebSocket(url);

    this._ws.onopen = () => {
      this._retries = 0;
      console.debug('[SyncWS] Connected');
    };

    this._ws.onmessage = (e) => {
      try {
        const event = JSON.parse(e.data);
        if (this._onMessage) this._onMessage(event);
      } catch {
        /* ignore malformed frames */
      }
    };

    this._ws.onclose = (e) => {
      if (this._manualClose) return;
      console.debug(`[SyncWS] Closed (${e.code}). Retry ${this._retries + 1}/${MAX_RETRIES}`);
      this._scheduleReconnect();
    };

    this._ws.onerror = () => {
      /* onclose fires next — handled there */
    };
  }

  _scheduleReconnect() {
    if (this._retries >= MAX_RETRIES) {
      console.warn('[SyncWS] Max retries reached. Giving up.');
      return;
    }
    const delay = Math.min(BASE_DELAY_MS * 2 ** this._retries, 30000);
    this._retries++;
    this._retryTimer = setTimeout(() => this._open(), delay);
  }
}

export default new SyncWebSocket();
