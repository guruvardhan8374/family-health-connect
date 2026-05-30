import { Activity, Droplets, Moon, ArrowUpRight, Flame, Heart, MapPin, ShieldAlert, Plus, Zap } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import FamilyMap from '../components/FamilyMap';
import { Link } from 'react-router-dom';

const heartRateData = [
  { time: '08:00', value: 68 },
  { time: '10:00', value: 72 },
  { time: '12:00', value: 85 },
  { time: '14:00', value: 74 },
  { time: '16:00', value: 90 },
  { time: '18:00', value: 82 },
  { time: '20:00', value: 70 },
];

const familyMembers = [
  { id: 1, name: 'Mom', role: 'Elderly', status: 'Healthy', battery: '85%', avatar: 'https://i.pravatar.cc/150?u=mom' },
  { id: 2, name: 'Dad', role: 'Elderly', status: 'At Home', battery: '92%', avatar: 'https://i.pravatar.cc/150?u=dad' },
  { id: 3, name: 'Pravi', role: 'You', status: 'Active', battery: '64%', avatar: 'https://i.pravatar.cc/150?u=pravi' },
];

export default function Dashboard() {
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
        {familyMembers.map((member) => (
          <div key={member.id} className="bg-white/70 backdrop-blur-md p-5 rounded-[2rem] border border-navy-100 shadow-sm hover:shadow-xl hover:translate-y-[-4px] transition-all duration-300 group">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center space-x-3">
                <div className="relative">
                  <img src={member.avatar} alt={member.name} className="w-12 h-12 rounded-full border-2 border-brand-200" />
                  <div className="absolute -bottom-1 -right-1 w-4 h-4 bg-emerald-500 border-2 border-white rounded-full"></div>
                </div>
                <div>
                  <h3 className="font-bold text-navy-900">{member.name}</h3>
                  <p className="text-xs text-navy-400 font-medium uppercase tracking-wider">{member.role}</p>
                </div>
              </div>
              <div className="text-right">
                <span className="inline-flex items-center px-2 py-1 rounded-lg bg-emerald-50 text-emerald-600 text-[10px] font-bold">
                  {member.status}
                </span>
              </div>
            </div>
            
            <div className="grid grid-cols-2 gap-3 mt-6">
              <div className="bg-navy-50 p-3 rounded-2xl">
                <p className="text-[10px] text-navy-400 font-bold uppercase tracking-tight">Heart Rate</p>
                <p className="text-lg font-bold text-navy-900 mt-1">72 <span className="text-xs text-navy-400 font-medium">bpm</span></p>
              </div>
              <div className="bg-navy-50 p-3 rounded-2xl">
                <p className="text-[10px] text-navy-400 font-bold uppercase tracking-tight">Steps</p>
                <p className="text-lg font-bold text-navy-900 mt-1">4.2k <span className="text-xs text-navy-400 font-medium">steps</span></p>
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Main Analytics Card */}
        <div className="lg:col-span-2 bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-sm relative overflow-hidden">
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

        {/* Location / Safety Card */}
        <div className="bg-gradient-to-br from-navy-900 to-navy-800 p-8 rounded-[2.5rem] text-white shadow-2xl relative overflow-hidden">
          <div className="absolute top-0 right-0 p-8 opacity-10">
            <Zap className="w-32 h-32" />
          </div>
          <div className="relative z-10 flex flex-col h-full">
            <div className="flex items-center space-x-2 mb-6">
              <div className="w-2 h-2 bg-emerald-400 rounded-full animate-ping"></div>
              <span className="text-xs font-bold uppercase tracking-widest text-emerald-400">Live Safety Protocol</span>
            </div>
            <h3 className="text-2xl font-bold mb-4">All family members are within safe zones.</h3>
            <p className="text-navy-300 text-sm mb-8 leading-relaxed">
              Geo-fencing is active for Dad and Mom. You will be notified instantly if they leave the predefined safety perimeter.
            </p>
            <div className="mt-auto">
              <div className="flex -space-x-3 mb-6">
                <img src="https://i.pravatar.cc/150?u=mom" className="w-10 h-10 rounded-full border-2 border-navy-800" />
                <img src="https://i.pravatar.cc/150?u=dad" className="w-10 h-10 rounded-full border-2 border-navy-800" />
              </div>
              <button className="w-full bg-white/10 hover:bg-white/20 text-white font-bold py-3 rounded-2xl border border-white/10 transition-all">
                Manage Geo-fences
              </button>
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
