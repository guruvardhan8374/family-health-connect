import { useState } from 'react';
import { Search, UserCircle, LogOut, ChevronDown } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import UserAvatar from './UserAvatar';

export default function Topbar() {
  const [showProfile, setShowProfile] = useState(false);
  const { user, logout } = useAuth();
  const displayName = user?.username || user?.first_name || localStorage.getItem('username') || 'User';

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
        {/* Profile */}
        <div className="relative">
          <button 
            onClick={() => setShowProfile(!showProfile)}
            className="flex items-center space-x-2 pl-4 border-l border-navy-100 hover:opacity-80 transition-all"
          >
            <UserAvatar
              src={user?.profile_picture}
              name={displayName}
              size="sm"
              className="w-9 h-9"
            />
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
