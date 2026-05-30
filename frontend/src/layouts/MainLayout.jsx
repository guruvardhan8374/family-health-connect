import { useEffect } from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from '../components/Sidebar';
import Topbar from '../components/Topbar';
import AIChatbot from '../components/AIChatbot';
import { requestForToken, onMessageListener } from '../utils/notifications';
import api from '../utils/api';
import { applyTheme } from '../utils/theme';

export default function MainLayout() {
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

    requestForToken();
    onMessageListener().then(payload => {
      console.log('New Message Received: ', payload);
    });
  }, []);
  return (
    <div className="flex h-screen overflow-hidden bg-navy-50">
      <Sidebar />
      <div className="flex flex-col flex-1 overflow-hidden">
        <Topbar />
        <main className="flex-1 overflow-y-auto p-6 relative">
          <Outlet />
          <AIChatbot />
        </main>
      </div>
    </div>
  );
}
