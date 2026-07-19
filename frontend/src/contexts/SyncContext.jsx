/**
 * SyncContext.jsx
 * ───────────────
 * Provides real-time sync events from the backend WebSocket to any React component.
 * Also handles offline detection and automatic flushing of the offline queue.
 *
 * Supported events (from backend SyncConsumer):
 *   settings.update  · health.update  · family.update  · emergency.alert
 *   chat.message     · notification.new · reminder.update · location.update
 *
 * Usage:
 *   import { useSyncEvent, useSync } from '../contexts/SyncContext';
 *   useSyncEvent('chat.message', (event) => { ... });
 *   const { connected, isOnline } = useSync();
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
import OfflineQueue from '../utils/offlineQueue';
import api from '../utils/api';

const SyncContext = createContext(null);

// ─── Tiny event emitter ────────────────────────────────────────────────────────
class EventBus {
  constructor() { this._listeners = {}; }

  on(type, fn) {
    if (!this._listeners[type]) this._listeners[type] = new Set();
    this._listeners[type].add(fn);
    return () => this._listeners[type].delete(fn);
  }

  emit(type, payload) {
    (this._listeners[type] || new Set()).forEach((fn) => fn(payload));
    (this._listeners['*'] || new Set()).forEach((fn) => fn(payload));
  }
}

const bus = new EventBus();

// ─── Provider ─────────────────────────────────────────────────────────────────

export function SyncProvider({ children }) {
  const [connected, setConnected] = useState(false);
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const [pendingCount, setPendingCount] = useState(OfflineQueue.getAll().length);
  const tokenRef = useRef(null);

  // ── Forward WebSocket events to the event bus ──────────────────────────────
  const handleMessage = useCallback((event) => {
    bus.emit(event.type, event);
  }, []);

  // ── WebSocket connect / reconnect ──────────────────────────────────────────
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

    connectIfLoggedIn();

    const onStorage = (e) => {
      if (e.key === 'access_token') {
        if (e.newValue) {
          tokenRef.current = e.newValue;
          SyncWS.updateToken(e.newValue);
        } else {
          SyncWS.disconnect();
          setConnected(false);
          tokenRef.current = null;
        }
      }
    };

    window.addEventListener('storage', onStorage);
    const pollId = setInterval(connectIfLoggedIn, 5000);

    return () => {
      window.removeEventListener('storage', onStorage);
      clearInterval(pollId);
      SyncWS.disconnect();
    };
  }, [handleMessage]);

  // ── Offline / online detection ─────────────────────────────────────────────
  useEffect(() => {
    const onOnline = async () => {
      setIsOnline(true);
      console.info('[SyncContext] Back online — flushing offline queue...');
      if (OfflineQueue.hasPending()) {
        await OfflineQueue.flush(api);
        setPendingCount(OfflineQueue.getAll().length);
      }
    };

    const onOffline = () => {
      setIsOnline(false);
      setConnected(false);
      console.warn('[SyncContext] Went offline.');
    };

    window.addEventListener('online', onOnline);
    window.addEventListener('offline', onOffline);

    return () => {
      window.removeEventListener('online', onOnline);
      window.removeEventListener('offline', onOffline);
    };
  }, []);

  return (
    <SyncContext.Provider value={{ connected, isOnline, pendingCount, bus }}>
      {children}
    </SyncContext.Provider>
  );
}

// ─── Hooks ────────────────────────────────────────────────────────────────────

/**
 * Subscribe to a specific sync event type.
 * @param {string} eventType  e.g. 'chat.message', 'health.update'
 * @param {Function} handler  called with the full event object each time
 * @param {Array} deps        extra deps for useCallback
 */
export function useSyncEvent(eventType, handler, deps = []) {
  const stableHandler = useCallback(handler, deps); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    return bus.on(eventType, stableHandler);
  }, [eventType, stableHandler]);
}

export const useSync = () => {
  const ctx = useContext(SyncContext);
  if (!ctx) throw new Error('useSync must be used inside SyncProvider');
  return ctx;
};
