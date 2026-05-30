import { Link, useLocation } from 'react-router-dom';
import { Home, HeartPulse, Users, MessageCircle, ShieldAlert, Settings, Brain, Activity } from 'lucide-react';
import { cn } from '../utils/cn';

const navItems = [
  { name: 'Dashboard', path: '/', icon: Home },
  { name: 'Health Hub', path: '/health', icon: HeartPulse },
  { name: 'Intelligence', path: '/ai-intelligence', icon: Brain },
  { name: 'Comparison', path: '/health-comparison', icon: Activity },
  { name: 'Family', path: '/family', icon: Users },
  { name: 'Chat', path: '/chat', icon: MessageCircle },
  { name: 'Settings', path: '/settings', icon: Settings },
];

export default function Sidebar() {
  const location = useLocation();

  return (
    <div className="w-64 bg-white border-r border-navy-100 flex flex-col justify-between hidden md:flex">
      <div>
        <div className="h-16 flex items-center px-6 border-b border-navy-100">
          <HeartPulse className="w-8 h-8 text-brand-500 mr-2" />
          <span className="text-xl font-bold text-navy-900 tracking-tight">FamilyConnect</span>
        </div>
        <nav className="p-4 space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;
            return (
              <Link
                key={item.name}
                to={item.path}
                className={cn(
                  "flex items-center px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200 group",
                  isActive 
                    ? "bg-brand-50 text-brand-600" 
                    : "text-navy-500 hover:bg-navy-50 hover:text-navy-900"
                )}
              >
                <Icon className={cn(
                  "w-5 h-5 mr-3 transition-colors", 
                  isActive ? "text-brand-500" : "text-navy-400 group-hover:text-navy-600"
                )} />
                {item.name}
              </Link>
            );
          })}
        </nav>
      </div>
      
      <div className="p-4">
        <Link
          to="/emergency"
          className="flex items-center justify-center w-full px-4 py-3 bg-red-50 text-red-600 rounded-xl text-sm font-bold hover:bg-red-100 transition-colors border border-red-100 shadow-sm"
        >
          <ShieldAlert className="w-5 h-5 mr-2" />
          SOS Emergency
        </Link>
      </div>
    </div>
  );
}
