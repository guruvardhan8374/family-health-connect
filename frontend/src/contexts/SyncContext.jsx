/**
 * SyncContext.jsx
 * ───────────────
 * Provides real-time sync events from the backend WebSocket to any React component.
 *
 * Usage:
 *   // 1. Wrap in SyncProvider (done in App.jsx)
 *   // 2. In any component:
 *   import { useSyncEvent } from '../contexts/SyncContext';
 *   useSyncEvent('settings.update', (event) => {
 *     if (event.section === 'theme') applyTheme(event.data);
 *   });
 *
 * Event shape (from backend SyncConsumer):
 *   { type: 'settings.update' | 'health.update' | 'family.update' | 'emergency.alert',
 *     section: string,
 *     data: object }
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react';
import SyncWS from '../utils/syncWebSocket';

const SyncContext = createContext(null);

// ─── Tiny event emitter ────────────────────────────────────────────────────────
class EventBus {
  constructor() { this._listeners = {}; }

  on(type, fn) {
    if (!this._listeners[type]) this._listeners[type] = new Set();
    this._listeners[type].add(fn);
    return () => this._listeners[type].delete(fn);   // returns unsubscribe fn
  }

  emit(type, payload) {
    (this._listeners[type] || new Set()).forEach((fn) => fn(payload));
    // Also emit '*' for catch-all listeners
    (this._listeners['*'] || new Set()).forEach((fn) => fn(payload));
  }
}

const bus = new EventBus();

// ─── Provider ─────────────────────────────────────────────────────────────────

export function SyncProvider({ children }) {
  const [connected, setConnected] = useState(false);
  const tokenRef = useRef(null);

  const handleMessage = useCallback((event) => {
    // Forward every WS event to the bus
    bus.emit(event.type, event);
  }, []);

  useEffect(() => {
    const connectIfLoggedIn = () => {
      const token = localStorage.getItem('access_token');
      if (token && token !== tokenRef.current) {
        tokenRef.current = token;
        SyncWS.connect(token, (event) => {
          setConnected(true);
          handleMessage(event);
        });
      }
    };

    // Connect immediately if already logged in
    connectIfLoggedIn();

    // Re-check on storage changes (login / token refresh)
    const onStorage = (e) => {
      if (e.key === 'access_token') {
        if (e.newValue) {
          tokenRef.current = e.newValue;
          SyncWS.updateToken(e.newValue);
        } else {
          // Token removed → logout
          SyncWS.disconnect();
          setConnected(false);
          tokenRef.current = null;
        }
      }
    };

    window.addEventListener('storage', onStorage);

    // Poll for token every 5 s (catches same-tab logins where storage event doesn't fire)
    const pollId = setInterval(connectIfLoggedIn, 5000);

    return () => {
      window.removeEventListener('storage', onStorage);
      clearInterval(pollId);
      SyncWS.disconnect();
    };
  }, [handleMessage]);

  return (
    <SyncContext.Provider value={{ connected }}>
      {children}
    </SyncContext.Provider>
  );
}

// ─── Hook ─────────────────────────────────────────────────────────────────────

/**
 * Subscribe to a specific sync event type.
 *
 * @param {string} eventType - e.g. 'settings.update', 'health.update'
 * @param {Function} handler - called with the full event object each time it fires
 * @param {Array} deps       - extra dependencies for useCallback (like normal)
 */
export function useSyncEvent(eventType, handler, deps = []) {
  const stableHandler = useCallback(handler, deps); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    return bus.on(eventType, stableHandler);       // returns unsubscribe
  }, [eventType, stableHandler]);
}

export const useSync = () => {
  const ctx = useContext(SyncContext);
  if (!ctx) throw new Error('useSync must be used inside SyncProvider');
  return ctx;
};
