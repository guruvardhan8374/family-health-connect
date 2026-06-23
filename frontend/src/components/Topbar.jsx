import { useState, useEffect } from 'react';
import { Bell, Search, UserCircle, LogOut, ChevronDown } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import api from '../utils/api';
import { useAuth } from '../contexts/AuthContext';

export default function Topbar() {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showProfile, setShowProfile] = useState(false);
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const displayName = user?.username || user?.first_name || localStorage.getItem('username') || 'User';
  const initials = displayName.charAt(0).toUpperCase();

  useEffect(() => {
    const fetchNotifications = async () => {
      try {
        // Correct path: /api/v1/notifications/unread-count/ (not /users/notifications/)
        const res = await api.get('/notifications/unread-count/');
        setUnreadCount(res.data.unread_count || 0);
        
        const listRes = await api.get('/notifications/');
        const data = listRes.data;
        setNotifications((Array.isArray(data) ? data : data.results || []).slice(0, 5));
      } catch (err) {
        // Silently ignore notification fetch errors
      }
    };
    fetchNotifications();
    const interval = setInterval(fetchNotifications, 30000); // Check every 30s
    return () => clearInterval(interval);
  }, []);

  const handleLogout = () => {
    logout();
  };

  return (
    <header className="h-16 bg-white border-b border-navy-100 flex items-center justify-between px-6 z-30">
      <div className="flex-1 max-w-xl">
        <div className="relative group">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-navy-400 group-focus-within:text-brand-500 transition-colors" />
          <input
            type="text"
            placeholder="Search family, health records..."
            className="w-full bg-navy-50 border-none rounded-full py-2 pl-10 pr-4 text-sm text-navy-900 focus:ring-2 focus:ring-brand-500/20 focus:bg-white outline-none transition-all"
          />
        </div>
      </div>
      
      <div className="flex items-center space-x-4 ml-4">
        {/* Notifications */}
        <div className="relative">
          <button 
            onClick={() => setShowNotifications(!showNotifications)}
            className="relative p-2 rounded-full text-navy-500 hover:bg-navy-50 transition-colors"
          >
            <Bell className="w-5 h-5" />
            {unreadCount > 0 && (
              <span className="absolute top-1.5 right-1.5 w-4 h-4 bg-red-500 text-white text-[10px] font-bold rounded-full border-2 border-white flex items-center justify-center">
                {unreadCount}
              </span>
            )}
          </button>

          {showNotifications && (
            <div className="absolute right-0 mt-2 w-80 bg-white rounded-2xl shadow-2xl border border-navy-100 overflow-hidden z-50 animate-in fade-in slide-in-from-top-2">
              <div className="p-4 border-b border-navy-100 flex justify-between items-center">
                <span className="font-bold text-navy-900">Notifications</span>
                <span className="text-xs text-brand-500 font-medium cursor-pointer">Mark all read</span>
              </div>
              <div className="max-h-96 overflow-y-auto">
                {notifications.length > 0 ? (
                  notifications.map((n) => (
                    <div key={n.id} className="p-4 hover:bg-navy-50 transition-colors border-b border-navy-50 last:border-0 cursor-pointer">
                      <p className="text-sm font-bold text-navy-900">{n.title}</p>
                      <p className="text-xs text-navy-500 mt-1 line-clamp-2">{n.message}</p>
                      <p className="text-[10px] text-navy-400 mt-2">{new Date(n.created_at).toLocaleString()}</p>
                    </div>
                  ))
                ) : (
                  <div className="p-8 text-center text-navy-400">
                    <p className="text-sm">All caught up! 🎉</p>
                  </div>
                )}
              </div>
              <div className="p-3 bg-navy-50 text-center">
                <button className="text-xs font-bold text-brand-600 hover:text-brand-700">View all notifications</button>
              </div>
            </div>
          )}
        </div>

        {/* Profile */}
        <div className="relative">
          <button 
            onClick={() => setShowProfile(!showProfile)}
            className="flex items-center space-x-2 pl-4 border-l border-navy-100 hover:opacity-80 transition-all"
          >
            <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-brand-500 to-brand-400 flex items-center justify-center text-white font-bold shadow-md shadow-brand-500/20">
              {initials}
            </div>
            <div className="text-left hidden sm:block">
              <p className="text-sm font-bold text-navy-900 leading-none">{displayName}</p>
              <p className="text-[10px] text-navy-400 mt-1 uppercase font-bold tracking-wider">{user?.role || 'Member'}</p>
            </div>
            <ChevronDown className="w-4 h-4 text-navy-400" />
          </button>

          {showProfile && (
            <div className="absolute right-0 mt-2 w-48 bg-white rounded-2xl shadow-2xl border border-navy-100 overflow-hidden z-50 p-2">
              <button className="w-full flex items-center space-x-2 p-3 rounded-xl hover:bg-navy-50 text-navy-600 text-sm font-medium transition-all">
                <UserCircle className="w-4 h-4" />
                <span>My Profile</span>
              </button>
              <button 
                onClick={handleLogout}
                className="w-full flex items-center space-x-2 p-3 rounded-xl hover:bg-red-50 text-red-600 text-sm font-medium transition-all"
              >
                <LogOut className="w-4 h-4" />
                <span>Sign Out</span>
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
