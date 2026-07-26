import { useState, useEffect } from 'react';
import { Activity, Droplets, Moon, ArrowUpRight, Flame, Heart, MapPin, ShieldAlert, Plus, Zap } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import FamilyMap from '../components/FamilyMap';
import { Link } from 'react-router-dom';
import api from '../utils/api';
import { useSyncEvent } from '../contexts/SyncContext';

const heartRateData = [
  { time: '08:00', value: 68 },
  { time: '10:00', value: 72 },
  { time: '12:00', value: 85 },
  { time: '14:00', value: 74 },
  { time: '16:00', value: 90 },
  { time: '18:00', value: 82 },
  { time: '20:00', value: 70 },
];

export default function Dashboard() {
  const [members, setMembers] = useState([]);
  const currentUserId = parseInt(localStorage.getItem('user_id') || '0');

  useEffect(() => {
    const fetchData = async () => {
      try {
        const savedGroupId = localStorage.getItem('active_family_group_id');
        const query = savedGroupId ? `?group_id=${savedGroupId}` : '';
        const [healthRes, mapRes] = await Promise.allSettled([
          api.get(`/health/family-summary/${query}`),
          api.get(`/family/members/${query}`)
        ]);
        
        const healthData = healthRes.status === 'fulfilled' ? (healthRes.value.data || []) : [];
        const mapData = mapRes.status === 'fulfilled' ? (Array.isArray(mapRes.value.data) ? mapRes.value.data : (mapRes.value.data.results || [])) : [];

        const combined = healthData.map(hd => {
          const md = mapData.find(m => (m.user_details && m.user_details.id === hd.user_id) || m.user === hd.user_id);
          return {
            ...hd,
            location: md?.latest_location,
            battery: md?.latest_location?.battery_level
          };
        });
        setMembers(combined);
      } catch (err) {
        console.error('Failed to fetch dashboard data:', err);
      }
    };
    fetchData();
  }, []);

  useSyncEvent('health.update', (event) => {
    const data = event.data;
    if (!data || !data.user_id) return;
    setMembers(prev => prev.map(m => {
      if (m.user_id === data.user_id) {
        return { ...m, latest_snapshot: data };
      }
      return m;
    }));
  });

  useSyncEvent('location.update', (event) => {
    const data = event.data;
    if (!data || !data.user_id) return;
    setMembers(prev => prev.map(m => {
      if (m.user_id === data.user_id) {
        return { ...m, location: data, battery: data.battery_level };
      }
      return m;
    }));
  });

  // Derived stats for the generic health pulse (you could fetch these if desired, kept placeholder structure for now)
  const familyNames = members.map(m => m.username).slice(0, 3).join(', ') || 'your family circle';

  return (
    <div className="space-y-8 pb-12">
      {/* Header */}
      <header className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-4xl font-bold text-navy-900 tracking-tight">Family Health Hub</h1>
          <p className="text-navy-500 mt-2 text-lg">Your private family ecosystem is active and secure.</p>
        </div>
        
        <div className="flex items-center space-x-3">
          <Link to="/emergency" className="bg-red-500 hover:bg-red-600 text-white font-bold px-6 py-3 rounded-2xl shadow-lg shadow-red-500/30 transition-all flex items-center group">
            <ShieldAlert className="w-5 h-5 mr-2 group-hover:scale-110 transition-transform" />
            SOS Emergency
          </Link>
          <button className="p-3 bg-white border border-navy-100 rounded-2xl shadow-sm text-navy-500 hover:text-brand-500 transition-colors">
            <Plus className="w-6 h-6" />
          </button>
        </div>
      </header>

      {/* Family Overview Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        {members.length === 0 ? (
          <div className="col-span-full text-center p-8 bg-white rounded-[2rem] text-navy-400 border border-navy-100">
            Loading family data...
          </div>
        ) : (
          members.map((member) => {
            const isSelf = member.user_id === currentUserId;
            const snapshot = member.latest_snapshot || {};
            const hrVal = (snapshot.heart_rate !== null && snapshot.heart_rate !== undefined && snapshot.heart_rate > 0) ? snapshot.heart_rate : 72;
            const stepsVal = (snapshot.steps !== null && snapshot.steps !== undefined) ? snapshot.steps : 0;
            const hr = `${hrVal} bpm`;
            const steps = (stepsVal >= 1000) ? (stepsVal / 1000).toFixed(1) + 'k steps' : `${stepsVal} steps`;
            const isOnline = member.location?.is_online;
            const status = isOnline ? 'Online' : (member.location?.last_seen_formatted || 'Offline');
            
            return (
              <div key={member.user_id} className="bg-white/70 backdrop-blur-md p-5 rounded-[2rem] border border-navy-100 shadow-sm hover:shadow-xl hover:translate-y-[-4px] transition-all duration-300 group">
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center space-x-3">
                    <div className="relative">
                      {member.profile_picture ? (
                        <img src={member.profile_picture} alt={member.username} className="w-12 h-12 rounded-full border-2 border-brand-200 object-cover" />
                      ) : (
                        <div className="w-12 h-12 rounded-full border-2 border-brand-200 bg-brand-50 flex items-center justify-center font-bold text-brand-500">
                          {member.username.charAt(0).toUpperCase()}
                        </div>
                      )}
                      <div className={`absolute -bottom-1 -right-1 w-4 h-4 rounded-full border-2 border-white ${isOnline || isSelf ? 'bg-emerald-500' : 'bg-slate-400'}`}></div>
                    </div>
                    <div>
                      <h3 className="font-bold text-navy-900">{member.username} {isSelf && '(You)'}</h3>
                      <p className="text-xs text-navy-400 font-medium uppercase tracking-wider">{member.role || member.label}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <span className={`inline-flex items-center px-2 py-1 rounded-lg text-[10px] font-bold ${isOnline || isSelf ? 'bg-emerald-50 text-emerald-600' : 'bg-slate-50 text-slate-500'}`}>
                      {status}
                    </span>
                  </div>
                </div>
                
                <div className="grid grid-cols-2 gap-3 mt-6">
                  <div className="bg-navy-50 p-3 rounded-2xl">
                    <p className="text-[10px] text-navy-400 font-bold uppercase tracking-tight">Heart Rate</p>
                    <p className="text-sm font-bold text-navy-900 mt-1">{hr}</p>
                  </div>
                  <div className="bg-navy-50 p-3 rounded-2xl">
                    <p className="text-[10px] text-navy-400 font-bold uppercase tracking-tight">Steps</p>
                    <p className="text-sm font-bold text-navy-900 mt-1">{steps}</p>
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      <div className="grid grid-cols-1 gap-8">
        {/* Main Analytics Card */}
        <div className="bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-sm relative overflow-hidden">
          <div className="flex items-center justify-between mb-8">
            <div>
              <h3 className="text-xl font-bold text-navy-900">Health Pulse</h3>
              <p className="text-navy-500 text-sm">Real-time vitals aggregation</p>
            </div>
            <div className="flex bg-navy-50 p-1 rounded-xl">
              <button className="px-4 py-1.5 rounded-lg text-xs font-bold bg-white text-navy-900 shadow-sm">Daily</button>
              <button className="px-4 py-1.5 rounded-lg text-xs font-bold text-navy-500 hover:text-navy-900">Weekly</button>
            </div>
          </div>
          
          <div className="h-64 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={heartRateData}>
                <defs>
                  <linearGradient id="dashboardPulse" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#14b8a6" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#14b8a6" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <XAxis dataKey="time" hide />
                <YAxis hide domain={['dataMin - 10', 'dataMax + 10']} />
                <Tooltip 
                  contentStyle={{ borderRadius: '20px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)' }}
                />
                <Area type="monotone" dataKey="value" stroke="#14b8a6" strokeWidth={4} fillOpacity={1} fill="url(#dashboardPulse)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>

          <div className="grid grid-cols-3 gap-6 mt-8">
            <div className="text-center">
              <p className="text-[10px] text-navy-400 font-bold uppercase tracking-widest mb-1">Avg Sleep</p>
              <p className="text-2xl font-black text-navy-900">8.2<span className="text-sm font-medium text-navy-400 ml-1">hrs</span></p>
            </div>
            <div className="text-center border-x border-navy-100">
              <p className="text-[10px] text-navy-400 font-bold uppercase tracking-widest mb-1">Avg Steps</p>
              <p className="text-2xl font-black text-navy-900">9.4<span className="text-sm font-medium text-navy-400 ml-1">k</span></p>
            </div>
            <div className="text-center">
              <p className="text-[10px] text-navy-400 font-bold uppercase tracking-widest mb-1">Avg HRV</p>
              <p className="text-2xl font-black text-navy-900">64<span className="text-sm font-medium text-navy-400 ml-1">ms</span></p>
            </div>
          </div>
        </div>
      </div>

      {/* Map Preview */}
      <div className="bg-white p-4 rounded-[2.5rem] border border-navy-100 shadow-sm">
        <div className="p-4 flex items-center justify-between">
          <h3 className="text-lg font-bold text-navy-900">Real-time Location Map</h3>
          <Link to="/family" className="text-brand-500 font-bold text-sm hover:underline">Full View</Link>
        </div>
        <FamilyMap />
      </div>
    </div>
  );
}
