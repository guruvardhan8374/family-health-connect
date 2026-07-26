import { useState, useEffect, useCallback } from 'react';
import { 
  Bell, AlertTriangle, MessageSquare, Users, HeartPulse, ShieldAlert, 
  CheckCheck, Trash2, Filter, RefreshCw, Volume2, Info, ChevronRight, Check
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import api from '../utils/api';
import { useSyncEvent } from '../contexts/SyncContext';

export default function Notifications() {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [activeTab, setActiveTab] = useState('ALL');
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [browserPushEnabled, setBrowserPushEnabled] = useState(
    typeof window !== 'undefined' && 'Notification' in window && Notification.permission === 'granted'
  );
  const navigate = useNavigate();

  const fetchNotifications = useCallback(async () => {
    try {
      setLoading(true);
      const [listRes, countRes] = await Promise.all([
        api.get('/notifications/'),
        api.get('/notifications/unread-count/')
      ]);
      
      const listData = Array.isArray(listRes.data) ? listRes.data : (listRes.data.results || []);
      setNotifications(listData);
      setUnreadCount(countRes.data.unread_count || 0);
    } catch (e) {
      console.error('Failed to fetch notifications:', e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchNotifications();
  }, [fetchNotifications]);

  // Real-time WebSocket event listener
  useSyncEvent('notification.new', (event) => {
    const data = event.data;
    if (!data || !data.id) return;

    setNotifications((prev) => [
      {
        id: data.id,
        title: data.title,
        message: data.message,
        type: data.type || 'SYSTEM',
        priority: data.priority || 'NORMAL',
        is_read: false,
        data: data.data || {},
        created_at: data.created_at || new Date().toISOString(),
        created_at_formatted: 'Just now',
      },
      ...prev.filter((n) => n.id !== data.id),
    ]);

    setUnreadCount((prev) => prev + 1);

    // Browser Push Notification if granted
    if (typeof window !== 'undefined' && 'Notification' in window && Notification.permission === 'granted') {
      try {
        new Notification(data.title, {
          body: data.message,
          icon: '/favicon.ico',
        });
      } catch (_) {}
    }
  });

  const requestBrowserPermission = async () => {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      const perm = await Notification.requestPermission();
      setBrowserPushEnabled(perm === 'granted');
    }
  };

  const markAsRead = async (id) => {
    try {
      await api.post(`/notifications/${id}/mark-read/`);
      setNotifications((prev) =>
        prev.map((n) => (n.id === id ? { ...n, is_read: true } : n))
      );
      setUnreadCount((prev) => Math.max(0, prev - 1));
    } catch (e) {
      console.error('Failed to mark read:', e);
    }
  };

  const markAllAsRead = async () => {
    try {
      await api.post('/notifications/mark-all-read/');
      setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })));
      setUnreadCount(0);
    } catch (e) {
      console.error('Failed to mark all read:', e);
    }
  };

  const deleteNotification = async (id, e) => {
    e.stopPropagation();
    try {
      await api.delete(`/notifications/${id}/`);
      setNotifications((prev) => prev.filter((n) => n.id !== id));
    } catch (e) {
      console.error('Failed to delete notification:', e);
    }
  };

  const deleteAllNotifications = async () => {
    if (!window.confirm('Are you sure you want to clear all notifications?')) return;
    try {
      await api.delete('/notifications/delete-all/');
      setNotifications([]);
      setUnreadCount(0);
    } catch (e) {
      console.error('Failed to delete all notifications:', e);
    }
  };

  const handleNotificationClick = (item) => {
    if (!item.is_read) {
      markAsRead(item.id);
    }

    const type = (item.type || '').toUpperCase();
    const data = item.data || {};

    if (data.action_url) {
      navigate(data.action_url);
      return;
    }

    switch (type) {
      case 'EMERGENCY':
      case 'SOS':
        navigate('/emergency');
        break;
      case 'CHAT':
        navigate('/chat');
        break;
      case 'FAMILY':
        navigate('/family');
        break;
      case 'HEALTH':
      case 'REMINDER':
      case 'MEDICINE':
      case 'WATER':
      case 'SLEEP':
        navigate('/health');
        break;
      default:
        navigate('/settings');
        break;
    }
  };

  const getIcon = (type, priority) => {
    const t = (type || '').toUpperCase();
    if (priority === 'HIGH' || priority === 'URGENT' || t === 'EMERGENCY' || t === 'SOS') {
      return <ShieldAlert className="w-5 h-5 text-red-500" />;
    }
    switch (t) {
      case 'CHAT':
        return <MessageSquare className="w-5 h-5 text-blue-500" />;
      case 'FAMILY':
        return <Users className="w-5 h-5 text-teal-500" />;
      case 'HEALTH':
      case 'MEDICINE':
      case 'WATER':
      case 'SLEEP':
      case 'REMINDER':
        return <HeartPulse className="w-5 h-5 text-purple-500" />;
      default:
        return <Info className="w-5 h-5 text-slate-500" />;
    }
  };

  const filteredNotifications = notifications.filter((item) => {
    const matchesTab =
      activeTab === 'ALL' ||
      (activeTab === 'UNREAD' && !item.is_read) ||
      (activeTab === 'SOS' && (item.type === 'EMERGENCY' || item.type === 'SOS')) ||
      (activeTab === 'CHAT' && item.type === 'CHAT') ||
      (activeTab === 'FAMILY' && item.type === 'FAMILY') ||
      (activeTab === 'HEALTH' && (item.type === 'HEALTH' || item.type === 'REMINDER' || item.type === 'MEDICINE')) ||
      (activeTab === 'SYSTEM' && item.type === 'SYSTEM');

    const matchesSearch =
      !searchTerm ||
      item.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.message.toLowerCase().includes(searchTerm.toLowerCase());

    return matchesTab && matchesSearch;
  });

  return (
    <div className="p-6 max-w-5xl mx-auto space-y-6 animate-in fade-in">
      {/* Top Banner Header */}
      <div className="bg-gradient-to-r from-teal-600 to-emerald-700 rounded-3xl p-6 text-white shadow-xl flex flex-col md:flex-row justify-between items-start md:items-center space-y-4 md:space-y-0">
        <div>
          <div className="flex items-center space-x-3">
            <div className="p-3 bg-white/10 backdrop-blur-md rounded-2xl">
              <Bell className="w-8 h-8 text-white" />
            </div>
            <div>
              <h1 className="text-2xl font-black">Notification Center</h1>
              <p className="text-teal-100 text-sm mt-0.5">
                Real-time updates, emergency alerts, and family notifications
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center space-x-3">
          {!browserPushEnabled && (
            <button
              onClick={requestBrowserPermission}
              className="px-4 py-2 bg-white/20 hover:bg-white/30 text-white rounded-xl text-xs font-bold transition-all flex items-center space-x-2 backdrop-blur-sm"
            >
              <Volume2 className="w-4 h-4" />
              <span>Enable Push</span>
            </button>
          )}
          {unreadCount > 0 && (
            <button
              onClick={markAllAsRead}
              className="px-4 py-2 bg-white text-teal-800 hover:bg-teal-50 rounded-xl text-xs font-bold transition-all flex items-center space-x-2 shadow-md"
            >
              <CheckCheck className="w-4 h-4" />
              <span>Mark All Read ({unreadCount})</span>
            </button>
          )}
          {notifications.length > 0 && (
            <button
              onClick={deleteAllNotifications}
              className="px-3 py-2 bg-red-500/20 hover:bg-red-500/30 text-white rounded-xl text-xs font-bold transition-all flex items-center space-x-1 backdrop-blur-sm"
            >
              <Trash2 className="w-4 h-4" />
              <span>Clear All</span>
            </button>
          )}
        </div>
      </div>

      {/* Controls Bar: Search & Filter Tabs */}
      <div className="bg-white dark:bg-slate-900 rounded-2xl p-4 border border-slate-200 dark:border-slate-800 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row justify-between items-center gap-4">
          {/* Tabs */}
          <div className="flex items-center space-x-1 overflow-x-auto w-full sm:w-auto pb-2 sm:pb-0 scrollbar-none">
            {[
              { key: 'ALL', label: 'All' },
              { key: 'UNREAD', label: `Unread (${unreadCount})` },
              { key: 'SOS', label: 'SOS' },
              { key: 'FAMILY', label: 'Family' },
              { key: 'CHAT', label: 'Chat' },
              { key: 'HEALTH', label: 'Health' },
              { key: 'SYSTEM', label: 'System' },
            ].map((tab) => (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={`px-4 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${
                  activeTab === tab.key
                    ? 'bg-teal-500 text-white shadow-md shadow-teal-500/20'
                    : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* Search & Refresh */}
          <div className="flex items-center space-x-2 w-full sm:w-auto">
            <div className="relative flex-1 sm:w-64">
              <Filter className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Filter notifications..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-2 bg-slate-50 dark:bg-slate-800 rounded-xl text-xs border border-slate-200 dark:border-slate-700 focus:outline-none focus:ring-2 focus:ring-teal-500/30"
              />
            </div>
            <button
              onClick={fetchNotifications}
              className="p-2 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 text-slate-600 dark:text-slate-300 rounded-xl transition-all"
              title="Refresh"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>
      </div>

      {/* Notification Items List */}
      <div className="space-y-3">
        {loading && notifications.length === 0 ? (
          <div className="text-center py-12 bg-white dark:bg-slate-900 rounded-3xl border border-slate-200 dark:border-slate-800">
            <RefreshCw className="w-8 h-8 text-teal-500 animate-spin mx-auto" />
            <p className="text-slate-500 text-sm mt-3 font-medium">Loading notifications...</p>
          </div>
        ) : filteredNotifications.length === 0 ? (
          <div className="text-center py-16 bg-white dark:bg-slate-900 rounded-3xl border border-slate-200 dark:border-slate-800 p-8">
            <div className="w-16 h-16 bg-teal-50 dark:bg-teal-900/20 text-teal-500 rounded-full flex items-center justify-center mx-auto mb-4">
              <Bell className="w-8 h-8" />
            </div>
            <h3 className="text-lg font-bold text-slate-800 dark:text-white">No notifications found</h3>
            <p className="text-slate-500 text-xs mt-1 max-w-md mx-auto">
              You are all caught up! When family alerts, chat messages, or reminders arrive, they will appear here live.
            </p>
          </div>
        ) : (
          filteredNotifications.map((item) => {
            const isUnread = !item.is_read;
            return (
              <div
                key={item.id}
                onClick={() => handleNotificationClick(item)}
                className={`group p-4 rounded-2xl border transition-all cursor-pointer flex items-start space-x-4 relative overflow-hidden ${
                  isUnread
                    ? 'bg-white dark:bg-slate-900 border-teal-500/40 dark:border-teal-500/30 shadow-md hover:shadow-lg'
                    : 'bg-slate-50/70 dark:bg-slate-900/50 border-slate-200 dark:border-slate-800 opacity-80 hover:opacity-100'
                }`}
              >
                {/* Unread Accent Bar */}
                {isUnread && (
                  <div className="absolute left-0 top-0 bottom-0 w-1.5 bg-teal-500 rounded-l-2xl"></div>
                )}

                {/* Type Icon */}
                <div
                  className={`p-3 rounded-2xl flex-shrink-0 ${
                    item.type === 'EMERGENCY' || item.type === 'SOS'
                      ? 'bg-red-50 dark:bg-red-950/40 text-red-500'
                      : item.type === 'CHAT'
                      ? 'bg-blue-50 dark:bg-blue-950/40 text-blue-500'
                      : item.type === 'FAMILY'
                      ? 'bg-teal-50 dark:bg-teal-950/40 text-teal-500'
                      : 'bg-slate-100 dark:bg-slate-800 text-slate-600'
                  }`}
                >
                  {getIcon(item.type, item.priority)}
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-2">
                      <h4
                        className={`text-sm font-bold truncate ${
                          isUnread ? 'text-slate-900 dark:text-white' : 'text-slate-700 dark:text-slate-300'
                        }`}
                      >
                        {item.title}
                      </h4>
                      {isUnread && (
                        <span className="w-2 h-2 rounded-full bg-teal-500 animate-pulse"></span>
                      )}
                    </div>
                    <span className="text-[11px] text-slate-400 font-medium whitespace-nowrap ml-2">
                      {item.created_at_formatted || new Date(item.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </span>
                  </div>

                  <p className="text-xs text-slate-600 dark:text-slate-400 mt-1 line-clamp-2 leading-relaxed">
                    {item.message}
                  </p>

                  <div className="flex items-center justify-between mt-3 pt-2 border-t border-slate-100 dark:border-slate-800/60 text-[11px]">
                    <span className="text-slate-400 font-semibold uppercase tracking-wider text-[10px]">
                      {item.type || 'SYSTEM'}
                    </span>

                    <div className="flex items-center space-x-2">
                      {isUnread && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            markAsRead(item.id);
                          }}
                          className="text-teal-600 dark:text-teal-400 hover:underline font-bold flex items-center space-x-1"
                        >
                          <Check className="w-3 h-3" />
                          <span>Mark Read</span>
                        </button>
                      )}
                      <button
                        onClick={(e) => deleteNotification(item.id, e)}
                        className="text-slate-400 hover:text-red-500 transition-colors p-1 rounded-lg hover:bg-red-50 dark:hover:bg-red-950/30"
                        title="Delete"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                      <ChevronRight className="w-4 h-4 text-slate-400 group-hover:translate-x-0.5 transition-transform" />
                    </div>
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
