import { useState, useEffect } from 'react';
import { Users, Heart, Zap, Droplets, Moon, ArrowRight, Loader2, Info } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Radar, RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis } from 'recharts';
import api from '../utils/api';

export default function HealthComparison() {
  const [members, setMembers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchMemberData = async () => {
      try {
        const res = await api.get('/family/members/');
        // In a real app, we'd fetch actual aggregate health data for each member
        // For this demo, we mock the health comparison data
        const membersWithHealth = res.data.map(m => ({
          name: m.user_details.username,
          heartRate: 60 + Math.random() * 30,
          steps: 2000 + Math.random() * 8000,
          sleep: 6 + Math.random() * 3,
          oxygen: 95 + Math.random() * 4,
          stress: Math.random() * 100,
          hydration: 1 + Math.random() * 2
        }));
        setMembers(membersWithHealth);
      } catch (err) {
        console.error('Failed to fetch members');
      } finally {
        setLoading(false);
      }
    };
    fetchMemberData();
  }, []);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center h-full space-y-4">
        <Loader2 className="w-12 h-12 text-brand-500 animate-spin" />
        <p className="text-navy-500 font-bold">Syncing family health metrics...</p>
      </div>
    );
  }

  const radarData = members.map(m => ({
    subject: m.name,
    A: m.heartRate,
    fullMark: 120,
  }));

  return (
    <div className="space-y-8 pb-12">
      <header>
        <h1 className="text-4xl font-bold text-navy-900 tracking-tight">Family Health Comparison</h1>
        <p className="text-navy-500 mt-2 text-lg">Compare vitals and activity across all family members.</p>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Heart Rate Comparison */}
        <div className="bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-sm">
          <h3 className="text-xl font-bold text-navy-900 mb-6 flex items-center">
            <Heart className="w-6 h-6 text-red-500 mr-2" />
            Heart Rate (Avg BPM)
          </h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={members}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{fill: '#64748b', fontSize: 12, fontWeight: 700}} />
                <YAxis axisLine={false} tickLine={false} tick={{fill: '#64748b', fontSize: 12}} />
                <Tooltip contentStyle={{borderRadius: '20px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)'}} />
                <Bar dataKey="heartRate" fill="#ef4444" radius={[10, 10, 10, 10]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Steps Comparison */}
        <div className="bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-sm">
          <h3 className="text-xl font-bold text-navy-900 mb-6 flex items-center">
            <Zap className="w-6 h-6 text-brand-500 mr-2" />
            Daily Steps Activity
          </h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={members}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{fill: '#64748b', fontSize: 12, fontWeight: 700}} />
                <YAxis axisLine={false} tickLine={false} tick={{fill: '#64748b', fontSize: 12}} />
                <Tooltip contentStyle={{borderRadius: '20px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)'}} />
                <Bar dataKey="steps" fill="#14b8a6" radius={[10, 10, 10, 10]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Wellness Radar */}
      <div className="bg-navy-900 p-8 rounded-[2.5rem] text-white shadow-2xl">
        <div className="flex flex-col md:flex-row gap-12 items-center">
          <div className="flex-1 space-y-6">
            <h3 className="text-2xl font-bold">Family Wellness Radar</h3>
            <p className="text-navy-400 leading-relaxed">
              This advanced visualization compares heart rate stability across the family. 
              The closer the point to the outer edge, the higher the cardiovascular exertion during the period.
            </p>
            <div className="space-y-4">
              <div className="flex items-center p-4 bg-white/5 rounded-2xl border border-white/10">
                <Info className="w-5 h-5 text-brand-400 mr-4" />
                <p className="text-sm">Consistent patterns across the family indicate synchronized lifestyles.</p>
              </div>
            </div>
          </div>
          
          <div className="w-full md:w-[400px] h-[350px]">
            <ResponsiveContainer width="100%" height="100%">
              <RadarChart cx="50%" cy="50%" outerRadius="80%" data={members}>
                <PolarGrid stroke="#334155" />
                <PolarAngleAxis dataKey="name" tick={{fill: '#94a3b8', fontSize: 12}} />
                <PolarRadiusAxis angle={30} domain={[0, 150]} tick={false} axisLine={false} />
                <Radar name="HR" dataKey="heartRate" stroke="#14b8a6" fill="#14b8a6" fillOpacity={0.6} />
                <Radar name="Stress" dataKey="stress" stroke="#ef4444" fill="#ef4444" fillOpacity={0.4} />
              </RadarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
}
