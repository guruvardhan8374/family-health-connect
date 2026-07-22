import { useEffect, useState } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import Sidebar from '../components/Sidebar';
import Topbar from '../components/Topbar';
import { requestForToken, onMessageListener } from '../utils/notifications';
import api from '../utils/api';
import { applyTheme } from '../utils/theme';
import { useSyncEvent } from '../contexts/SyncContext';
import { useAuth } from '../contexts/AuthContext';

export default function MainLayout() {
  const [activeSOS, setActiveSOS] = useState(null);
  const navigate = useNavigate();
  const { refreshUser } = useAuth();

  useSyncEvent('profile.picture_updated', (event) => {
    refreshUser();
  });

  useSyncEvent('emergency.alert', (event) => {
    if (event.data) {
      if (event.data.status === 'RESOLVED' || event.data.status === 'FALSE_ALARM' || event.data.is_resolved) {
        setActiveSOS((prev) => (prev && prev.id === event.data.id ? null : prev));
      } else {
        setActiveSOS({
          id: event.data.id,
          message: event.data.message || 'Emergency! I need help immediately.',
          triggeredBy: event.data.triggered_by || 'Family Member',
          lat: event.data.location_lat,
          lng: event.data.location_lng,
          googleMapsLink: event.data.google_maps_link || `https://www.google.com/maps/search/?api=1&query=${event.data.location_lat},${event.data.location_lng}`
        });
      }
    }
  });

  useEffect(() => {
    const fetchAndApplyTheme = async () => {
      try {
        const res = await api.get('/settings/theme/');
        applyTheme(res.data.theme_color, res.data.dark_mode);
      } catch (err) {
        const localColor = localStorage.getItem('theme_color') || 'blue';
        const localDark = localStorage.getItem('theme_dark_mode') === 'true';
        applyTheme(localColor, localDark);
      }
    };
    fetchAndApplyTheme();

    requestForToken().then((token) => {
      if (token) {
        api.post('/users/register-fcm/', { fcm_token: token })
           .catch((err) => console.debug('FCM register failed:', err));
      }
    });

    onMessageListener().then(payload => {
      console.log('New Message Received: ', payload);
    });
  }, []);

  return (
    <div className="flex h-screen overflow-hidden bg-navy-50">
      <Sidebar />
      <div className="flex flex-col flex-1 overflow-hidden">
        {activeSOS && (
          <div className="bg-red-600 text-white px-6 py-3 flex items-center justify-between shadow-lg shadow-red-600/20 z-40 animate-pulse border-b border-red-700">
            <div className="flex items-center space-x-3">
              <span className="text-xl">🚨</span>
              <div>
                <p className="font-bold text-sm tracking-wide">
                  EMERGENCY SOS: {activeSOS.triggeredBy} needs help!
                </p>
                <p className="text-xs text-red-100 mt-0.5">
                  Message: "{activeSOS.message}"
                  {activeSOS.lat && ` • Location: ${activeSOS.lat.toFixed(4)}, ${activeSOS.lng.toFixed(4)}`}
                </p>
              </div>
            </div>
            <div className="flex items-center space-x-3 shrink-0">
              {activeSOS.lat && (
                <a 
                  href={activeSOS.googleMapsLink} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="bg-white text-red-600 hover:bg-red-50 px-3 py-1 rounded-full text-xs font-bold transition-all shadow-sm"
                >
                  Track on Map
                </a>
              )}
              <button 
                onClick={() => navigate('/emergency')}
                className="bg-red-700 hover:bg-red-800 text-white px-3 py-1 rounded-full text-xs font-bold transition-all border border-red-500"
              >
                Open Protocol
              </button>
              <button 
                onClick={() => setActiveSOS(null)}
                className="text-red-200 hover:text-white font-medium text-xs px-2"
              >
                Dismiss
              </button>
            </div>
          </div>
        )}
        <Topbar />
        <main className="flex-1 overflow-y-auto p-6 relative">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
