import { useState, useEffect, useRef } from 'react';

/**
 * useHealthWebSocket — custom hook to establish connection with the
 * Django Channels ws/health/ endpoint and retrieve live vital updates.
 */
export default function useHealthWebSocket(onUpdate, onAlert) {
  const [isConnected, setIsConnected] = useState(false);
  const socketRef = useRef(null);
  const reconnectTimeoutRef = useRef(null);

  useEffect(() => {
    const token = localStorage.getItem('access_token');
    if (!token) return;

    const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
    const wsScheme = apiBaseUrl.startsWith('https') ? 'wss' : 'ws';
    const wsUrl = `${wsScheme}://${apiBaseUrl.replace(/^https?:\/\//, '')}/ws/health/?token=${token}`;

    const connect = () => {
      console.log('Connecting to health WebSocket...');
      const ws = new WebSocket(wsUrl);
      socketRef.current = ws;

      ws.onopen = () => {
        console.log('Health WebSocket connected.');
        setIsConnected(true);
      };

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          if (data.type === 'health.update' && onUpdate) {
            onUpdate(data.snapshot);
          } else if (data.type === 'health.alert' && onAlert) {
            onAlert(data.alerts);
          }
        } catch (err) {
          console.error('Error parsing health WebSocket data:', err);
        }
      };

      ws.onclose = (event) => {
        console.log('Health WebSocket disconnected. Code:', event.code);
        setIsConnected(false);
        if (event.code !== 4001) {
          // Attempt reconnect
          reconnectTimeoutRef.current = setTimeout(connect, 3000);
        }
      };

      ws.onerror = (err) => {
        console.error('Health WebSocket error:', err);
        ws.close();
      };
    };

    connect();

    return () => {
      if (socketRef.current) {
        socketRef.current.close();
      }
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
    };
  }, [onUpdate, onAlert]);

  return { isConnected };
}
