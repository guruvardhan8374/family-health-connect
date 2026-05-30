import { useState, useEffect } from 'react';
import i18n from '../i18n';
import api from '../utils/api';
import { useAuth } from '../contexts/AuthContext';
import { applyTheme } from '../utils/theme';
import {
  User, Bell, Shield, Eye, Moon, Sun,
  Camera, Lock, Key, Trash2, LogOut,
  CheckCircle, AlertCircle, Loader2, Globe, ShieldAlert
} from 'lucide-react';

export default function Settings() {
  const { logout, refreshUser } = useAuth();
  
  // Navigation State
  const [activeTab, setActiveTab] = useState('profile');

  // Loaders & Feedback
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMsg, setSuccessMsg] = useState('');
  const [errorMsg, setErrorMsg] = useState('');

  // Modals & Forms
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [passwordForm, setPasswordForm] = useState({
    old_password: '',
    new_password: '',
    confirm_password: ''
  });

  // Settings State
  const [profile, setProfile] = useState({
    username: '',
    email: '',
    profile_picture: '',
    phone_number: '',
    bio: '',
    emergency_contact: '',
    emergency_phone: '',
    preferred_language: 'en',
    timezone: 'UTC',
    date_of_birth: '',
    gender: '',
    blood_group: '',
    address: ''
  });

  const [notifications, setNotifications] = useState({
    push_notifications: true,
    medicine_reminders: true,
    health_reminders: true,
    emergency_alerts: true,
    family_notifications: true,
    chat_notifications: true,
    email_notifications: true
  });

  const [privacy, setPrivacy] = useState({
    profile_visibility: 'FAMILY',
    health_data_visibility: 'FAMILY',
    family_visibility: 'FAMILY',
    location_sharing: true,
    emergency_visibility: 'FAMILY'
  });

  const [theme, setTheme] = useState({
    dark_mode: false,
    theme_color: 'blue'
  });

  const [account, setAccount] = useState({
    two_factor_auth_enabled: false,
    delete_account_enabled: true,
    change_password_enabled: true
  });

  // Load Settings from APIs
  useEffect(() => {
    const fetchSettings = async () => {
      setLoading(true);
      setErrorMsg('');
      try {
        const [profileRes, notifRes, privacyRes, themeRes, accountRes] = await Promise.all([
          api.get('/settings/profile/'),
          api.get('/settings/notifications/'),
          api.get('/settings/privacy/'),
          api.get('/settings/theme/'),
          api.get('/settings/account/')
        ]);

        if (profileRes.data) setProfile(profileRes.data);
        if (notifRes.data) setNotifications(notifRes.data);
        if (privacyRes.data) setPrivacy(privacyRes.data);
        if (themeRes.data) {
          setTheme(themeRes.data);
          applyTheme(themeRes.data.theme_color, themeRes.data.dark_mode);
        }
        if (accountRes.data) setAccount(accountRes.data);
      } catch (err) {
        console.error('Failed to load settings:', err);
        setErrorMsg('Error loading settings. Please try again.');
      } finally {
        setLoading(false);
      }
    };
    fetchSettings();
  }, []);

  // Show status banner temporarily
  const triggerFeedback = (message, isError = false) => {
    if (isError) {
      setErrorMsg(message);
      setSuccessMsg('');
    } else {
      setSuccessMsg(message);
      setErrorMsg('');
      setTimeout(() => setSuccessMsg(''), 4000);
    }
  };

  // Profile Save
  const handleSaveProfile = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const res = await api.put('/settings/profile/', profile);
      setProfile(res.data);
      triggerFeedback('Profile settings updated successfully!');
      refreshUser(); // Sync user data with topbar/avatar
    } catch (err) {
      console.error(err);
      const errs = err.response?.data;
      const firstError = errs ? Object.values(errs)[0]?.[0] || Object.values(errs)[0] : '';
      triggerFeedback(firstError || 'Failed to update profile settings.', true);
    } finally {
      setSaving(false);
    }
  };

  // File Upload to Data URL Mock/Real
  const handleProfilePictureUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    
    // Validate file size and type
    if (!file.type.startsWith('image/')) {
      triggerFeedback('Please select a valid image file.', true);
      return;
    }

    const reader = new FileReader();
    reader.onloadend = async () => {
      const base64String = reader.result;
      setSaving(true);
      try {
        const res = await api.put('/settings/profile/', {
          ...profile,
          profile_picture: base64String
        });
        setProfile(res.data);
        triggerFeedback('Profile picture uploaded successfully!');
        refreshUser();
      } catch (err) {
        console.error(err);
        triggerFeedback('Failed to upload profile picture.', true);
      } finally {
        setSaving(false);
      }
    };
    reader.readAsDataURL(file);
  };

  // Save specific settings endpoint helper (toggles & selects)
  const saveSectionSettings = async (url, payload, updater) => {
    try {
      const res = await api.put(url, payload);
      updater(res.data);
      // Optional: flash brief micro-success feedback
    } catch (err) {
      console.error(err);
      triggerFeedback('Failed to auto-save change.', true);
    }
  };

  // Instant toggles for notifications
  const handleNotificationToggle = (key) => {
    const updated = { ...notifications, [key]: !notifications[key] };
    setNotifications(updated);
    saveSectionSettings('/settings/notifications/', updated, setNotifications);
  };

  // Instant toggles/selects for privacy
  const handlePrivacyChange = (key, val) => {
    const updated = { ...privacy, [key]: val };
    setPrivacy(updated);
    saveSectionSettings('/settings/privacy/', updated, setPrivacy);
  };

  // Theme change handlers
  const handleThemeColorChange = (color) => {
    const updated = { ...theme, theme_color: color };
    setTheme(updated);
    applyTheme(color, theme.dark_mode);
    saveSectionSettings('/settings/theme/', updated, setTheme);
  };

  const handleDarkModeToggle = () => {
    const updated = { ...theme, dark_mode: !theme.dark_mode };
    setTheme(updated);
    applyTheme(theme.theme_color, !theme.dark_mode);
    saveSectionSettings('/settings/theme/', updated, setTheme);
  };

  // Account 2FA toggle
  const handleTwoFactorToggle = () => {
    const updated = { ...account, two_factor_auth_enabled: !account.two_factor_auth_enabled };
    setAccount(updated);
    saveSectionSettings('/settings/account/', updated, setAccount);
  };

  // Change Password
  const handleChangePassword = async (e) => {
    e.preventDefault();
    setSaving(true);
    setErrorMsg('');
    try {
      await api.put('/settings/account/', {
        ...account,
        ...passwordForm
      });
      triggerFeedback('Password changed successfully!');
      setPasswordForm({ old_password: '', new_password: '', confirm_password: '' });
    } catch (err) {
      console.error(err);
      const data = err.response?.data;
      const msg = data?.new_password?.[0] || data?.confirm_password?.[0] || data?.old_password?.[0] || data?.error || 'Failed to change password.';
      triggerFeedback(msg, true);
    } finally {
      setSaving(false);
    }
  };

  // Delete Account
  const handleDeleteAccount = async () => {
    setSaving(true);
    try {
      await api.delete('/settings/account/');
      logout();
    } catch (err) {
      console.error(err);
      triggerFeedback('Failed to delete account.', true);
      setSaving(false);
    }
  };

  const tabs = [
    { id: 'profile', name: 'Profile Settings', icon: User },
    { id: 'notifications', name: 'Notifications', icon: Bell },
    { id: 'privacy', name: 'Privacy Settings', icon: Eye },
    { id: 'theme', name: 'Theme Settings', icon: Moon },
    { id: 'account', name: 'Account Settings', icon: Shield },
  ];

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] space-y-4">
        <Loader2 className="w-12 h-12 text-brand-500 animate-spin" />
        <p className="text-navy-500 font-medium animate-pulse">Loading settings...</p>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto space-y-8 pb-12">
      {/* Feedback Banner */}
      {successMsg && (
        <div className="fixed top-20 right-6 z-50 flex items-center space-x-3 bg-emerald-50 border border-emerald-200 text-emerald-800 px-6 py-4 rounded-2xl shadow-xl animate-slide-in">
          <CheckCircle className="w-5 h-5 text-emerald-600 shrink-0" />
          <p className="text-sm font-semibold">{successMsg}</p>
        </div>
      )}
      {errorMsg && (
        <div className="fixed top-20 right-6 z-50 flex items-center space-x-3 bg-rose-50 border border-rose-200 text-rose-800 px-6 py-4 rounded-2xl shadow-xl animate-slide-in">
          <AlertCircle className="w-5 h-5 text-rose-600 shrink-0" />
          <p className="text-sm font-semibold">{errorMsg}</p>
        </div>
      )}

      <header className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-extrabold text-navy-900 tracking-tight dark:text-white">Settings</h1>
          <p className="text-navy-500 mt-1 dark:text-navy-400">Configure your personal profile, notification preferences, privacy, and account security.</p>
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Navigation Sidebar (Vertical on Desktop, Horizontal Scroll on Mobile) */}
        <aside className="lg:col-span-3 flex lg:flex-col gap-2 overflow-x-auto pb-2 lg:pb-0 scrollbar-none border-b border-navy-100 lg:border-b-0 lg:border-r lg:pr-6 border-navy-200">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-center space-x-3 px-5 py-3.5 rounded-2xl text-sm font-bold transition-all duration-200 shrink-0 ${
                  isActive
                    ? 'bg-brand-500 text-white shadow-lg shadow-brand-500/25 scale-[1.02]'
                    : 'text-navy-500 hover:bg-white hover:text-navy-900 dark:hover:bg-navy-800 dark:text-navy-400'
                }`}
              >
                <Icon className="w-5 h-5" />
                <span>{tab.name}</span>
              </button>
            );
          })}
        </aside>

        {/* Content Area */}
        <main className="lg:col-span-9 space-y-6">
          {/* PROFILE SETTINGS TAB */}
          {activeTab === 'profile' && (
            <section className="bg-white dark:bg-navy-900/40 backdrop-blur-md p-6 md:p-8 rounded-[2rem] border border-navy-100 dark:border-navy-800 shadow-xl shadow-navy-100/10 space-y-8 transition-all">
              <div className="flex flex-col sm:flex-row items-center gap-6 pb-6 border-b border-navy-100 dark:border-navy-800">
                <div className="relative group">
                  {profile.profile_picture ? (
                    <img
                      src={profile.profile_picture}
                      alt="Avatar"
                      className="w-28 h-28 rounded-3xl object-cover shadow-md border-4 border-white dark:border-navy-900"
                    />
                  ) : (
                    <div className="w-28 h-28 rounded-3xl bg-gradient-to-br from-brand-400 to-brand-600 flex items-center justify-center text-4xl font-extrabold text-white shadow-inner">
                      {profile.username?.charAt(0).toUpperCase() || 'U'}
                    </div>
                  )}
                  <label className="absolute -bottom-2 -right-2 p-2.5 bg-navy-900 text-white rounded-xl shadow-lg border-4 border-white dark:border-navy-800 cursor-pointer hover:scale-110 active:scale-95 transition-all">
                    <Camera className="w-4 h-4" />
                    <input
                      type="file"
                      accept="image/*"
                      onChange={handleProfilePictureUpload}
                      className="hidden"
                    />
                  </label>
                </div>
                <div className="text-center sm:text-left">
                  <h3 className="text-2xl font-bold text-navy-900 dark:text-white">{profile.username || 'User Profile'}</h3>
                  <p className="text-navy-400 text-sm mt-1">{profile.email}</p>
                  <span className="inline-block mt-2 text-xs font-black uppercase tracking-wider text-brand-600 bg-brand-50 dark:bg-brand-900/30 px-3 py-1.5 rounded-lg border border-brand-100 dark:border-brand-900/50">
                    Active Member
                  </span>
                </div>
              </div>

              <form onSubmit={handleSaveProfile} className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <label className="text-xs font-black uppercase tracking-widest text-navy-500 dark:text-navy-400">Username</label>
                    <input
                      required
                      type="text"
                      value={profile.username}
                      onChange={(e) => setProfile({ ...profile, username: e.target.value })}
                      className="w-full bg-navy-50 dark:bg-navy-900/80 border border-transparent dark:border-navy-800 rounded-xl py-3.5 px-4 text-navy-900 dark:text-white outline-none focus:border-brand-500 focus:ring-4 focus:ring-brand-500/10 transition-all font-medium"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-black uppercase tracking-widest text-navy-500 dark:text-navy-400">Phone Number</label>
                    <input
                      type="tel"
                      value={profile.phone_number || ''}
                      onChange={(e) => setProfile({ ...profile, phone_number: e.target.value })}
                      placeholder="e.g. +1 (555) 019-2834"
                      className="w-full bg-navy-50 dark:bg-navy-900/80 border border-transparent dark:border-navy-800 rounded-xl py-3.5 px-4 text-navy-900 dark:text-white outline-none focus:border-brand-500 focus:ring-4 focus:ring-brand-500/10 transition-all font-medium"
                    />
                  </div>
                  <div className="space-y-2 md:col-span-2">
                    <label className="text-xs font-black uppercase tracking-widest text-navy-500 dark:text-navy-400">Bio</label>
                    <textarea
                      rows={3}
                      value={profile.bio || ''}
                      onChange={(e) => setProfile({ ...profile, bio: e.target.value })}
                      placeholder="Tell us about yourself..."
                      className="w-full bg-navy-50 dark:bg-navy-900/80 border border-transparent dark:border-navy-800 rounded-xl py-3.5 px-4 text-navy-900 dark:text-white outline-none focus:border-brand-500 focus:ring-4 focus:ring-brand-500/10 transition-all font-medium resize-none"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-black uppercase tracking-widest text-navy-500 dark:text-navy-400">Emergency Contact Name</label>
                    <input
                      type="text"
                      value={profile.emergency_contact || ''}
                      onChange={(e) => setProfile({ ...profile, emergency_contact: e.target.value })}
                      placeholder="Emergency contact full name"
                      className="w-full bg-navy-50 dark:bg-navy-900/80 border border-transparent dark:border-navy-800 rounded-xl py-3.5 px-4 text-navy-900 dark:text-white outline-none focus:border-brand-500 focus:ring-4 focus:ring-brand-500/10 transition-all font-medium"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-black uppercase tracking-widest text-navy-500 dark:text-navy-400">Emergency Phone</label>
                    <input
                      type="tel"
                      value={profile.emergency_phone || ''}
                      onChange={(e) => setProfile({ ...profile, emergency_phone: e.target.value })}
                      placeholder="Emergency contact phone number"
                      className="w-full bg-navy-50 dark:bg-navy-900/80 border border-transparent dark:border-navy-800 rounded-xl py-3.5 px-4 text-navy-900 dark:text-white outline-none focus:border-brand-500 focus:ring-4 focus:ring-brand-500/10 transition-all font-medium"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-black uppercase tracking-widest text-navy-500 dark:text-navy-400">Preferred Language</label>
                    <select
                      value={profile.preferred_language}
                      onChange={(e) => {
                        setProfile({ ...profile, preferred_language: e.target.value });
                        i18n.changeLanguage(e.target.value);
                      }}
                      className="w-full bg-navy-50 dark:bg-navy-900/80 border border-transparent dark:border-navy-800 rounded-xl py-3.5 px-4 text-navy-900 dark:text-white outline-none focus:border-brand-500 focus:ring-4 focus:ring-brand-500/10 transition-all font-medium"
                    >
                      <option value="en">English (US)</option>
                      <option value="hi">हिंदी (Hindi)</option>
                      <option value="te">తెలుగు (Telugu)</option>
                      <option value="ta">தமிழ் (Tamil)</option>
                    </select>
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-black uppercase tracking-widest text-navy-500 dark:text-navy-400">Timezone</label>
                    <select
                      value={profile.timezone}
                      onChange={(e) => setProfile({ ...profile, timezone: e.target.value })}
                      className="w-full bg-navy-50 dark:bg-navy-900/80 border border-transparent dark:border-navy-800 rounded-xl py-3.5 px-4 text-navy-900 dark:text-white outline-none focus:border-brand-500 focus:ring-4 focus:ring-brand-500/10 transition-all font-medium"
                    >
                      <option value="UTC">UTC (Coordinated Universal Time)</option>
                      <option value="America/New_York">EST (Eastern Standard Time)</option>
                      <option value="Asia/Kolkata">IST (Indian Standard Time)</option>
                      <option value="Europe/London">GMT (Greenwich Mean Time)</option>
                    </select>
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={saving}
                  className="w-full sm:w-auto bg-brand-500 hover:bg-brand-600 active:scale-[0.98] disabled:bg-brand-400 text-white font-bold px-8 py-3.5 rounded-2xl transition-all shadow-lg shadow-brand-500/20 flex items-center justify-center space-x-2"
                >
                  {saving ? (
                    <Loader2 className="w-5 h-5 animate-spin" />
                  ) : (
                    <span>Save Profile Changes</span>
                  )}
                </button>
              </form>
            </section>
          )}

          {/* NOTIFICATION SETTINGS TAB */}
          {activeTab === 'notifications' && (
            <section className="bg-white dark:bg-navy-900/40 backdrop-blur-md p-6 md:p-8 rounded-[2rem] border border-navy-100 dark:border-navy-800 shadow-xl shadow-navy-100/10 space-y-6">
              <div>
                <h3 className="text-2xl font-bold text-navy-900 dark:text-white">Notification Settings</h3>
                <p className="text-navy-400 text-sm mt-1">Configure when and where you want to be notified. Changes save instantly.</p>
              </div>

              <div className="divide-y divide-navy-50 dark:divide-navy-800">
                {[
                  { key: 'push_notifications', name: 'Push Notifications', desc: 'Enable native device push alerts' },
                  { key: 'medicine_reminders', name: 'Medicine Reminders', desc: 'Alerts when it is time to take pills or doses' },
                  { key: 'health_reminders', name: 'Health Checkup Reminders', desc: 'Alerts for annual and weekly general checkups' },
                  { key: 'emergency_alerts', name: 'SOS & Emergency Alerts', desc: 'Instant notifications when a family member triggers SOS' },
                  { key: 'family_notifications', name: 'Family Network Alerts', desc: 'Updates on family member activities' },
                  { key: 'chat_notifications', name: 'Chat Messages', desc: 'Alerts for new incoming messaging threads' },
                  { key: 'email_notifications', name: 'Email Updates', desc: 'Receive summaries and digests via email' },
                ].map((item) => {
                  const isChecked = notifications[item.key];
                  return (
                    <div key={item.key} className="flex items-center justify-between py-4 first:pt-0 last:pb-0">
                      <div>
                        <p className="font-bold text-navy-900 dark:text-white text-sm">{item.name}</p>
                        <p className="text-xs text-navy-400 mt-0.5">{item.desc}</p>
                      </div>
                      <button
                        onClick={() => handleNotificationToggle(item.key)}
                        className={`w-12 h-6 rounded-full transition-all relative outline-none shrink-0 ${
                          isChecked ? 'bg-brand-500' : 'bg-navy-200 dark:bg-navy-800'
                        }`}
                      >
                        <div
                          className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-all ${
                            isChecked ? 'right-1' : 'left-1'
                          }`}
                        />
                      </button>
                    </div>
                  );
                })}
              </div>
            </section>
          )}

          {/* PRIVACY SETTINGS TAB */}
          {activeTab === 'privacy' && (
            <section className="bg-white dark:bg-navy-900/40 backdrop-blur-md p-6 md:p-8 rounded-[2rem] border border-navy-100 dark:border-navy-800 shadow-xl shadow-navy-100/10 space-y-6">
              <div>
                <h3 className="text-2xl font-bold text-navy-900 dark:text-white">Privacy Preferences</h3>
                <p className="text-navy-400 text-sm mt-1">Manage visibility of your personal data. Changes save instantly.</p>
              </div>

              <div className="space-y-6">
                {[
                  { key: 'profile_visibility', name: 'Profile Visibility', desc: 'Who can view your basic profile card details' },
                  { key: 'health_data_visibility', name: 'Health Records Visibility', desc: 'Who is authorized to view health records and blood groups' },
                  { key: 'family_visibility', name: 'Family Link Visibility', desc: 'Who can see your family link tree memberships' },
                  { key: 'emergency_visibility', name: 'Emergency Details Visibility', desc: 'Who can view emergency contact phone numbers' },
                ].map((item) => (
                  <div key={item.key} className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-4 bg-navy-50 dark:bg-navy-900/50 rounded-2xl border border-navy-100/50 dark:border-navy-800/40">
                    <div>
                      <p className="font-bold text-navy-900 dark:text-white text-sm">{item.name}</p>
                      <p className="text-xs text-navy-400 mt-0.5">{item.desc}</p>
                    </div>
                    <select
                      value={privacy[item.key]}
                      onChange={(e) => handlePrivacyChange(item.key, e.target.value)}
                      className="bg-white dark:bg-navy-850 border border-navy-200 dark:border-navy-800 text-navy-900 dark:text-white rounded-xl py-2 px-3 text-sm font-bold focus:ring-2 focus:ring-brand-500/20 outline-none cursor-pointer"
                    >
                      <option value="PUBLIC">Public</option>
                      <option value="FAMILY">Family Only</option>
                      <option value="PRIVATE">Private</option>
                    </select>
                  </div>
                ))}

                <div className="flex items-center justify-between p-4 bg-navy-50 dark:bg-navy-900/50 rounded-2xl border border-navy-100/50 dark:border-navy-800/40">
                  <div>
                    <p className="font-bold text-navy-900 dark:text-white text-sm">Location Sharing</p>
                    <p className="text-xs text-navy-400 mt-0.5">Allow family heads to view real-time location history mapping</p>
                  </div>
                  <button
                    onClick={() => handlePrivacyChange('location_sharing', !privacy.location_sharing)}
                    className={`w-12 h-6 rounded-full transition-all relative outline-none shrink-0 ${
                      privacy.location_sharing ? 'bg-brand-500' : 'bg-navy-200 dark:bg-navy-800'
                    }`}
                  >
                    <div
                      className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-all ${
                        privacy.location_sharing ? 'right-1' : 'left-1'
                      }`}
                    />
                  </button>
                </div>
              </div>
            </section>
          )}

          {/* THEME SETTINGS TAB */}
          {activeTab === 'theme' && (
            <section className="bg-white dark:bg-navy-900/40 backdrop-blur-md p-6 md:p-8 rounded-[2rem] border border-navy-100 dark:border-navy-800 shadow-xl shadow-navy-100/10 space-y-8">
              <div>
                <h3 className="text-2xl font-bold text-navy-900 dark:text-white">Theme & Display</h3>
                <p className="text-navy-400 text-sm mt-1">Personalize the styling and feel of the app interface. Changes save instantly.</p>
              </div>

              <div className="space-y-6">
                <div className="flex items-center justify-between p-5 bg-navy-50 dark:bg-navy-900/50 rounded-2xl border border-navy-100/50 dark:border-navy-800/40">
                  <div className="flex items-center space-x-3">
                    {theme.dark_mode ? (
                      <Moon className="w-6 h-6 text-brand-500" />
                    ) : (
                      <Sun className="w-6 h-6 text-brand-500" />
                    )}
                    <div>
                      <p className="font-bold text-navy-900 dark:text-white text-sm">Dark Mode</p>
                      <p className="text-xs text-navy-400 mt-0.5">Toggle dark theme for night usage</p>
                    </div>
                  </div>
                  <button
                    onClick={handleDarkModeToggle}
                    className={`w-12 h-6 rounded-full transition-all relative outline-none shrink-0 ${
                      theme.dark_mode ? 'bg-brand-500' : 'bg-navy-200 dark:bg-navy-800'
                    }`}
                  >
                    <div
                      className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-all ${
                        theme.dark_mode ? 'right-1' : 'left-1'
                      }`}
                    />
                  </button>
                </div>

                <div className="space-y-3 p-5 bg-navy-50 dark:bg-navy-900/50 rounded-2xl border border-navy-100/50 dark:border-navy-800/40">
                  <p className="font-bold text-navy-900 dark:text-white text-sm">Theme Accent Color</p>
                  <p className="text-xs text-navy-400">Select your preferred accent brand color palette</p>
                  
                  <div className="flex flex-wrap gap-4 pt-3">
                    {[
                      { id: 'blue', name: 'Blue', color: 'bg-blue-500' },
                      { id: 'emerald', name: 'Emerald', color: 'bg-emerald-500' },
                      { id: 'indigo', name: 'Indigo', color: 'bg-indigo-500' },
                      { id: 'rose', name: 'Rose', color: 'bg-rose-500' },
                      { id: 'violet', name: 'Violet', color: 'bg-violet-500' },
                      { id: 'orange', name: 'Orange', color: 'bg-orange-500' },
                    ].map((colorObj) => (
                      <button
                        key={colorObj.id}
                        onClick={() => handleThemeColorChange(colorObj.id)}
                        className={`flex items-center space-x-2 px-4 py-2.5 rounded-xl border text-xs font-extrabold transition-all duration-200 hover:scale-105 ${
                          theme.theme_color === colorObj.id
                            ? 'bg-white dark:bg-navy-900 border-brand-500 shadow-md text-brand-600 ring-2 ring-brand-500/20'
                            : 'bg-white/50 dark:bg-navy-850 border-navy-200 dark:border-navy-800 text-navy-500 hover:text-navy-900'
                        }`}
                      >
                        <span className={`w-3.5 h-3.5 rounded-full ${colorObj.color}`} />
                        <span>{colorObj.name}</span>
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </section>
          )}

          {/* ACCOUNT SETTINGS TAB */}
          {activeTab === 'account' && (
            <div className="space-y-6">
              {/* Account details toggles */}
              <section className="bg-white dark:bg-navy-900/40 backdrop-blur-md p-6 md:p-8 rounded-[2rem] border border-navy-100 dark:border-navy-800 shadow-xl shadow-navy-100/10 space-y-6">
                <div>
                  <h3 className="text-2xl font-bold text-navy-900 dark:text-white">Security Settings</h3>
                  <p className="text-navy-400 text-sm mt-1">Manage secondary verification preferences.</p>
                </div>

                <div className="flex items-center justify-between p-4 bg-navy-50 dark:bg-navy-900/50 rounded-2xl border border-navy-100/50 dark:border-navy-800/40">
                  <div className="flex items-center space-x-3">
                    <Shield className="w-5 h-5 text-brand-500" />
                    <div>
                      <p className="font-bold text-navy-900 dark:text-white text-sm">Two-Factor Authentication</p>
                      <p className="text-xs text-navy-400 mt-0.5">Enforce email OTP prompt verification code on token sign-in requests</p>
                    </div>
                  </div>
                  <button
                    onClick={handleTwoFactorToggle}
                    className={`w-12 h-6 rounded-full transition-all relative outline-none shrink-0 ${
                      account.two_factor_auth_enabled ? 'bg-brand-500' : 'bg-navy-200 dark:bg-navy-800'
                    }`}
                  >
                    <div
                      className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-all ${
                        account.two_factor_auth_enabled ? 'right-1' : 'left-1'
                      }`}
                    />
                  </button>
                </div>
              </section>

              {/* Password update form */}
              <section className="bg-white dark:bg-navy-900/40 backdrop-blur-md p-6 md:p-8 rounded-[2rem] border border-navy-100 dark:border-navy-800 shadow-xl shadow-navy-100/10 space-y-6">
                <div className="flex items-center space-x-3">
                  <Lock className="w-6 h-6 text-brand-500" />
                  <div>
                    <h3 className="text-xl font-bold text-navy-900 dark:text-white">Change Password</h3>
                    <p className="text-navy-400 text-xs mt-0.5">Update credentials periodically for maximum data encryption protection.</p>
                  </div>
                </div>

                <form onSubmit={handleChangePassword} className="space-y-4 max-w-lg">
                  <div className="space-y-2">
                    <label className="text-xs font-black uppercase tracking-widest text-navy-500">Current Password</label>
                    <input
                      required
                      type="password"
                      value={passwordForm.old_password}
                      onChange={(e) => setPasswordForm({ ...passwordForm, old_password: e.target.value })}
                      placeholder="••••••••"
                      className="w-full bg-navy-50 dark:bg-navy-900/80 border border-transparent dark:border-navy-800 rounded-xl py-3 px-4 text-navy-900 dark:text-white outline-none focus:border-brand-500 focus:ring-4 focus:ring-brand-500/10 transition-all font-medium"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-black uppercase tracking-widest text-navy-500">New Password</label>
                    <input
                      required
                      type="password"
                      value={passwordForm.new_password}
                      onChange={(e) => setPasswordForm({ ...passwordForm, new_password: e.target.value })}
                      placeholder="••••••••"
                      className="w-full bg-navy-50 dark:bg-navy-900/80 border border-transparent dark:border-navy-800 rounded-xl py-3 px-4 text-navy-900 dark:text-white outline-none focus:border-brand-500 focus:ring-4 focus:ring-brand-500/10 transition-all font-medium"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-black uppercase tracking-widest text-navy-500">Confirm New Password</label>
                    <input
                      required
                      type="password"
                      value={passwordForm.confirm_password}
                      onChange={(e) => setPasswordForm({ ...passwordForm, confirm_password: e.target.value })}
                      placeholder="••••••••"
                      className="w-full bg-navy-50 dark:bg-navy-900/80 border border-transparent dark:border-navy-800 rounded-xl py-3 px-4 text-navy-900 dark:text-white outline-none focus:border-brand-500 focus:ring-4 focus:ring-brand-500/10 transition-all font-medium"
                    />
                  </div>

                  <button
                    type="submit"
                    disabled={saving}
                    className="bg-brand-500 hover:bg-brand-600 disabled:bg-brand-400 active:scale-[0.98] text-white font-bold px-6 py-3 rounded-xl transition-all shadow-md flex items-center justify-center space-x-2 text-sm"
                  >
                    {saving ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <>
                        <Key className="w-4 h-4" />
                        <span>Update Password</span>
                      </>
                    )}
                  </button>
                </form>
              </section>

              {/* Danger Zone */}
              <section className="bg-red-50/20 dark:bg-red-950/10 border border-red-200/50 dark:border-red-900/30 p-6 md:p-8 rounded-[2rem] space-y-6">
                <div>
                  <h3 className="text-xl font-bold text-red-700 dark:text-red-400">Danger Zone</h3>
                  <p className="text-navy-400 text-xs mt-1">Actions in this zone are permanent and can result in deletion of health logs.</p>
                </div>

                <div className="flex flex-col sm:flex-row gap-4 items-center justify-between pt-2">
                  <div className="text-center sm:text-left">
                    <p className="font-bold text-red-900 dark:text-red-400 text-sm">Delete Account</p>
                    <p className="text-xs text-navy-400">Permanently delete your profile and revoke family links</p>
                  </div>
                  <button
                    onClick={() => setShowDeleteModal(true)}
                    className="w-full sm:w-auto px-5 py-3 bg-red-600 hover:bg-red-700 text-white font-bold rounded-xl text-sm transition-all shadow-md shadow-red-600/10 flex items-center justify-center space-x-2"
                  >
                    <Trash2 className="w-4 h-4" />
                    <span>Delete Account</span>
                  </button>
                </div>

                <div className="flex flex-col sm:flex-row gap-4 items-center justify-between pt-2 border-t border-red-200/30">
                  <div className="text-center sm:text-left">
                    <p className="font-bold text-navy-900 dark:text-white text-sm font-bold">Sign Out</p>
                    <p className="text-xs text-navy-400">Log out of the current device session</p>
                  </div>
                  <button
                    onClick={logout}
                    className="w-full sm:w-auto px-5 py-3 bg-navy-100 hover:bg-navy-200 dark:bg-navy-800 dark:hover:bg-navy-700 text-navy-800 dark:text-white font-bold rounded-xl text-sm transition-all flex items-center justify-center space-x-2"
                  >
                    <LogOut className="w-4 h-4" />
                    <span>Logout</span>
                  </button>
                </div>
              </section>
            </div>
          )}
        </main>
      </div>

      {/* Account Deletion Modal */}
      {showDeleteModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-navy-950/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white dark:bg-navy-900 max-w-md w-full p-6 md:p-8 rounded-[2rem] border border-red-100 dark:border-red-950 shadow-2xl space-y-6">
            <div className="w-12 h-12 bg-red-100 dark:bg-red-900/30 rounded-2xl flex items-center justify-center text-red-600 dark:text-red-400">
              <ShieldAlert className="w-6 h-6" />
            </div>
            
            <div className="space-y-2">
              <h4 className="text-xl font-bold text-navy-900 dark:text-white">Delete your account?</h4>
              <p className="text-sm text-navy-400">
                Are you absolutely sure? This action is permanent and will delete all your family health profiles, connection records, logs, and medical history.
              </p>
            </div>

            <div className="flex gap-4 pt-2">
              <button
                disabled={saving}
                onClick={() => setShowDeleteModal(false)}
                className="flex-1 py-3 bg-navy-50 hover:bg-navy-100 dark:bg-navy-800 dark:hover:bg-navy-700 text-navy-800 dark:text-white text-sm font-bold rounded-xl transition-all"
              >
                Cancel
              </button>
              <button
                disabled={saving}
                onClick={handleDeleteAccount}
                className="flex-1 py-3 bg-red-600 hover:bg-red-700 disabled:bg-red-400 text-white text-sm font-bold rounded-xl transition-all shadow-md flex items-center justify-center space-x-2"
              >
                {saving ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <span>Delete Account</span>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
