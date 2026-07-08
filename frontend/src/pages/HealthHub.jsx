import { useState, useEffect, useCallback } from 'react';
import api from "../utils/api";
import { useSyncEvent } from '../contexts/SyncContext';
import { 
  Activity, Heart, Droplets, Moon, Flame, Wind, 
  Brain, Zap, Plus, ArrowUpRight, ArrowDownRight,
  ChevronRight, Calendar, RefreshCw
} from 'lucide-react';
import { 
  AreaChart, Area, XAxis, YAxis, CartesianGrid, 
  Tooltip, ResponsiveContainer, BarChart, Bar, Cell
} from 'recharts';

const dailyData = [
  { time: '12am', heart: 62, steps: 0, oxygen: 98 },
  { time: '4am', heart: 58, steps: 0, oxygen: 99 },
  { time: '8am', heart: 75, steps: 1200, oxygen: 98 },
  { time: '12pm', heart: 82, steps: 3500, oxygen: 97 },
  { time: '4pm', heart: 88, steps: 5800, oxygen: 98 },
  { time: '8pm', heart: 72, steps: 8432, oxygen: 99 },
  { time: '11pm', heart: 65, steps: 8432, oxygen: 98 },
];

const weeklyData = [
  { day: 'Mon', steps: 6500, sleep: 7.5 },
  { day: 'Tue', steps: 8200, sleep: 6.8 },
  { day: 'Wed', steps: 9100, sleep: 8.2 },
  { day: 'Thu', steps: 7400, sleep: 7.1 },
  { day: 'Fri', steps: 10500, sleep: 7.9 },
  { day: 'Sat', steps: 12000, sleep: 9.0 },
  { day: 'Sun', steps: 8432, sleep: 8.5 },
];

const familyMembers = [
  { id: 1, name: 'Pravi', avatar: 'https://i.pravatar.cc/150?u=pravi' },
  { id: 2, name: 'Mom', avatar: 'https://i.pravatar.cc/150?u=mom' },
  { id: 3, name: 'Dad', avatar: 'https://i.pravatar.cc/150?u=dad' },
];

const MetricCard = ({ title, value, unit, icon: Icon, color, trend, trendValue }) => (
  <div className="bg-white/70 backdrop-blur-md p-6 rounded-[2rem] border border-navy-100 shadow-sm hover:shadow-xl hover:translate-y-[-4px] transition-all duration-300 group">
    <div className="flex justify-between items-start mb-4">
      <div className={`p-3 rounded-2xl ${color} bg-opacity-10 group-hover:scale-110 transition-transform`}>
        <Icon className={`w-6 h-6 ${color.replace('bg-', 'text-')}`} />
      </div>
      {trend && (
        <div className={`flex items-center px-2 py-1 rounded-full text-xs font-bold ${trend === 'up' ? 'text-emerald-500 bg-emerald-50' : 'text-red-500 bg-red-50'}`}>
          {trend === 'up' ? <ArrowUpRight className="w-3 h-3 mr-1" /> : <ArrowDownRight className="w-3 h-3 mr-1" />}
          {trendValue}%
        </div>
      )}
    </div>
    <p className="text-navy-500 text-sm font-medium">{title}</p>
    <div className="mt-1 flex items-baseline space-x-1">
      <h3 className="text-2xl font-bold text-navy-900">{value}</h3>
      <span className="text-navy-400 text-sm font-medium">{unit}</span>
    </div>
  </div>
);
export default function HealthHub() {
  const [healthData, setHealthData] = useState(null);
  const [timeRange, setTimeRange] = useState('Daily');
  const [selectedMember, setSelectedMember] = useState(null);
  const [syncFlash, setSyncFlash] = useState(false);

  const fetchHealthData = useCallback(async () => {
    try {
      const response = await api.get('/health-records/');
      if (response.data.length > 0) {
        setHealthData(response.data[0]);
      }
    } catch (error) {
      console.error("Health fetch failed", error);
    }
  }, []);

  useEffect(() => {
    fetchHealthData();
  }, [fetchHealthData]);

  // ── Real-time sync: new health record added on mobile ──────────────────
  useSyncEvent('health.update', () => {
    setSyncFlash(true);
    fetchHealthData();
    setTimeout(() => setSyncFlash(false), 2500);
  }, [fetchHealthData]);

  return (
    <div className="space-y-8 pb-12">
      {/* Sync flash banner */}
      {syncFlash && (
        <div className="fixed top-20 right-6 z-50 flex items-center gap-2 bg-brand-500 text-white px-5 py-3 rounded-2xl shadow-xl animate-slide-in">
          <RefreshCw className="w-4 h-4 animate-spin" />
          <span className="text-sm font-bold">Health data updated from mobile</span>
        </div>
      )}
      {/* Header Section */}
      <header className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-bold text-navy-900 tracking-tight">Health Insights</h1>
          <p className="text-navy-500 mt-1">Deep dive into your family's health performance.</p>
        </div>
        
        <div className="flex items-center space-x-3">
          <div className="flex bg-white p-1 rounded-2xl border border-navy-100 shadow-sm">
            {['Daily', 'Weekly', 'Monthly'].map((range) => (
              <button
                key={range}
                onClick={() => setTimeRange(range)}
                className={`px-4 py-2 rounded-xl text-sm font-bold transition-all ${
                  timeRange === range ? 'bg-brand-500 text-white shadow-md shadow-brand-500/20' : 'text-navy-500 hover:text-navy-900'
                }`}
              >
                {range}
              </button>
            ))}
          </div>
          
          <button className="p-3 bg-white border border-navy-100 rounded-2xl shadow-sm text-navy-500 hover:text-brand-500 transition-colors">
            <Plus className="w-5 h-5" />
          </button>
        </div>
      </header>

      {/* Family Member Selector */}
      <div className="flex space-x-4 overflow-x-auto pb-2 scrollbar-hide">
        {familyMembers.map((member) => (
          <button
            key={member.id}
            onClick={() => setSelectedMember(member)}
            className={`flex items-center space-x-3 px-5 py-3 rounded-2xl border transition-all shrink-0 ${
              selectedMember?.id === member.id
                ? 'bg-brand-50 border-brand-200 shadow-sm' 
                : 'bg-white border-navy-100 hover:border-brand-200'
            }`}
          >
            <img src={member.avatar} alt={member.name} className="w-10 h-10 rounded-full border-2 border-white shadow-sm" />
            <span className={`font-bold ${selectedMember?.id === member.id ? 'text-brand-600' : 'text-navy-900'}`}>{member.name}</span>
            {selectedMember?.id === member.id && <div className="w-2 h-2 bg-brand-500 rounded-full"></div>}
          </button>
        ))}
      </div>

      {/* Main Metrics Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <MetricCard 
          title="Heart Rate" 
          value="72" 
          unit="bpm" 
          icon={Heart} 
          color="bg-red-500" 
          trend="up" 
          trendValue="2.4" 
        />
        <MetricCard 
          title="Daily Steps" 
          value="8,432" 
          unit="steps" 
          icon={Activity} 
          color="bg-brand-500" 
          trend="up" 
          trendValue="12" 
        />
        <MetricCard 
          title="Oxygen Level" 
          value="98" 
          unit="%" 
          icon={Wind} 
          color="bg-blue-500" 
          trend="down" 
          trendValue="0.5" 
        />
        <MetricCard 
          title="Sleep Quality" 
          value="8.5" 
          unit="hrs" 
          icon={Moon} 
          color="bg-indigo-500" 
          trend="up" 
          trendValue="8.1" 
        />
        <MetricCard 
          title="Calories" 
          value="1,840" 
          unit="kcal" 
          icon={Flame} 
          color="bg-orange-500" 
        />
        <MetricCard 
          title="Hydration" 
          value="1.2" 
          unit="L" 
          icon={Droplets} 
          color="bg-cyan-500" 
        />
        <MetricCard 
          title="Stress Level" 
          value="Low" 
          unit="" 
          icon={Brain} 
          color="bg-purple-500" 
        />
        <MetricCard 
          title="Blood Pressure" 
          value="120/80" 
          unit="mmHg" 
          icon={Zap} 
          color="bg-pink-500" 
        />
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Heart Rate Area Chart */}
        <div className="bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-sm">
          <div className="flex items-center justify-between mb-8">
            <div>
              <h3 className="text-xl font-bold text-navy-900">Heart Rate Trends</h3>
              <p className="text-navy-500 text-sm">Average 72 bpm today</p>
            </div>
            <button className="text-brand-600 font-bold text-sm flex items-center hover:translate-x-1 transition-transform">
              Full Report <ChevronRight className="w-4 h-4 ml-1" />
            </button>
          </div>
          
          <div className="h-72 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={dailyData}>
                <defs>
                  <linearGradient id="heartGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#ef4444" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis dataKey="time" axisLine={false} tickLine={false} tick={{fill: '#64748b', fontSize: 12}} dy={10} />
                <YAxis hide />
                <Tooltip 
                  contentStyle={{ borderRadius: '20px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)', padding: '12px' }}
                  itemStyle={{ fontWeight: 'bold' }}
                />
                <Area type="monotone" dataKey="heart" stroke="#ef4444" strokeWidth={4} fillOpacity={1} fill="url(#heartGradient)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Steps Bar Chart */}
        <div className="bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-sm">
          <div className="flex items-center justify-between mb-8">
            <div>
              <h3 className="text-xl font-bold text-navy-900">Weekly Activity</h3>
              <p className="text-navy-500 text-sm">Target: 10,000 steps/day</p>
            </div>
            <button className="p-2 bg-navy-50 text-navy-500 rounded-xl hover:bg-navy-100 transition-colors">
              <Calendar className="w-5 h-5" />
            </button>
          </div>
          
          <div className="h-72 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={weeklyData}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis dataKey="day" axisLine={false} tickLine={false} tick={{fill: '#64748b', fontSize: 12}} dy={10} />
                <YAxis hide />
                <Tooltip 
                  cursor={{fill: '#f8fafc'}}
                  contentStyle={{ borderRadius: '20px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)', padding: '12px' }}
                />
                <Bar dataKey="steps" radius={[10, 10, 0, 0]}>
                  {weeklyData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={index === 5 ? '#14b8a6' : '#ccfbf1'} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Health Analytics Insight Card */}
      <div className="bg-gradient-to-r from-navy-900 to-navy-800 p-8 rounded-[2.5rem] text-white shadow-2xl relative overflow-hidden group">
        <div className="absolute top-0 right-0 p-8 opacity-10 group-hover:scale-125 transition-transform duration-700">
          <Brain className="w-48 h-48" />
        </div>
        <div className="relative z-10 max-w-2xl">
          <div className="inline-flex items-center px-3 py-1 rounded-full bg-brand-500/20 text-brand-400 text-xs font-bold mb-4 border border-brand-500/30">
            <Zap className="w-3 h-3 mr-1" />
            AI HEALTH INSIGHT
          </div>
          <h2 className="text-2xl font-bold mb-3">Your Sleep Quality has improved by 15% this week</h2>
          <p className="text-navy-300 text-lg mb-6">
            We noticed that following your 8:00 PM wind-down routine has led to deeper REM sleep cycles. 
            Keep it up to maintain high cognitive performance!
          </p>
          <div className="flex flex-wrap gap-4">
            <button className="bg-brand-500 hover:bg-brand-600 text-white font-bold px-6 py-3 rounded-2xl transition-all shadow-lg shadow-brand-500/20">
              View Detailed Analysis
            </button>
            <button className="bg-white/10 hover:bg-white/20 text-white font-bold px-6 py-3 rounded-2xl transition-all border border-white/10">
              Dismiss
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
