import { useState, useEffect } from 'react';
import { Brain, TrendingUp, AlertCircle, Calendar, ArrowRight, ShieldCheck, Activity } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts';
import api from '../utils/api';
import VoiceInterface from '../components/VoiceInterface';

const data = [
  { name: 'Mon', score: 85 },
  { name: 'Tue', score: 78 },
  { name: 'Wed', score: 92 },
  { name: 'Thu', score: 88 },
  { name: 'Fri', score: 76 },
  { name: 'Sat', score: 80 },
  { name: 'Sun', score: 89 },
];

export default function AISummary() {
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchAIReport = async () => {
      try {
        setLoading(true);
        const res = await api.get('/health-records/health-intelligence/');
        const score = res.data.health_score || 70;
        const anomalies = res.data.anomalies || [];
        const suggestions = res.data.suggestions || [];
        
        // Merge anomalies and suggestions
        const insights = [];
        anomalies.forEach(a => {
          insights.push(`Anomaly warning: ${a.message} (${a.metric}: ${a.value})`);
        });
        insights.push(...suggestions);

        if (insights.length === 0) {
          insights.push(
            "Overall heart rates, sleep duration, and blood pressure are within ideal parameters.",
            "Continue logging metrics regularly to enable advanced anomaly alarms."
          );
        }

        setSummary({
          overallScore: score,
          trend: score >= 80 ? 'improving' : 'needs attention',
          insights: insights
        });
      } catch (err) {
        console.error("Failed to fetch AI report:", err);
        // Fallback report
        setSummary({
          overallScore: 75,
          trend: 'stable',
          insights: [
            "Maintain consistent hydration levels throughout the day.",
            "Aim for at least 7-8 hours of sleep for recovery.",
            "Ensure regular steps of 8,000+ daily."
          ]
        });
      } finally {
        setLoading(false);
      }
    };

    fetchAIReport();
  }, []);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center h-full space-y-4">
        <Brain className="w-12 h-12 text-brand-500 animate-pulse" />
        <p className="text-navy-500 font-bold animate-bounce">Analyzing your family's health patterns...</p>
      </div>
    );
  }

  return (
    <div className="max-w-5xl space-y-8 pb-12">
      <header className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-4xl font-bold text-navy-900 tracking-tight">AI Wellness Intelligence</h1>
          <p className="text-navy-500 mt-2 text-lg">Weekly aggregate analysis and predictive health warnings.</p>
        </div>
        <div className="flex items-center space-x-2 bg-white px-4 py-2 rounded-2xl border border-navy-100 shadow-sm">
          <Calendar className="w-5 h-5 text-brand-500" />
          <span className="font-bold text-navy-900">May 4 - May 11, 2026</span>
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Weekly Score Card */}
        <div className="bg-gradient-to-br from-brand-500 to-brand-600 p-8 rounded-[2.5rem] text-white shadow-2xl relative overflow-hidden flex flex-col justify-between">
          <div className="relative z-10">
            <p className="text-brand-100 font-bold uppercase tracking-widest text-xs mb-4">Overall Family Score</p>
            <div className="text-7xl font-black mb-2">{summary.overallScore}<span className="text-2xl opacity-50">/100</span></div>
            <div className="flex items-center space-x-2 text-brand-100">
              <TrendingUp className="w-5 h-5" />
              <span className="font-bold">5% Improvement from last week</span>
            </div>
          </div>
          <div className="absolute top-0 right-0 p-8 opacity-20 transform translate-x-8 -translate-y-8">
            <Brain className="w-48 h-48" />
          </div>
          <button className="relative z-10 w-full bg-white/10 hover:bg-white/20 text-white font-bold py-3 rounded-2xl border border-white/10 transition-all mt-8">
            View Full AI Report
          </button>
        </div>

        {/* Weekly Chart */}
        <div className="lg:col-span-2 bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-sm">
          <h3 className="text-xl font-bold text-navy-900 mb-6">Daily Wellness Trend</h3>
          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={data}>
                <Tooltip cursor={{fill: 'transparent'}} contentStyle={{borderRadius: '20px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)'}} />
                <Bar dataKey="score" radius={[10, 10, 10, 10]}>
                  {data.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.score > 80 ? '#14b8a6' : '#94a3b8'} />
                  ))}
                </Bar>
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{fill: '#64748b', fontSize: 12, fontWeight: 700}} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {/* AI Insights */}
        <div className="bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-sm space-y-6">
          <h3 className="text-xl font-bold text-navy-900 flex items-center">
            <ShieldCheck className="w-6 h-6 text-brand-500 mr-2" />
            Predictive Insights
          </h3>
          <div className="space-y-4">
            {summary.insights.map((insight, i) => (
              <div key={i} className="flex items-start p-4 bg-navy-50 rounded-2xl group hover:bg-white hover:shadow-md transition-all border border-transparent hover:border-navy-100">
                <div className={`p-2 rounded-xl mr-4 ${insight.includes('Anomaly') ? 'bg-red-50 text-red-500' : 'bg-brand-50 text-brand-500'}`}>
                  {insight.includes('Anomaly') ? <AlertCircle className="w-4 h-4" /> : <Activity className="w-4 h-4" />}
                </div>
                <p className="text-sm text-navy-700 leading-relaxed font-medium">{insight}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Quick Actions */}
        <div className="space-y-6">
          <div className="bg-navy-900 p-8 rounded-[2.5rem] text-white shadow-2xl">
            <h3 className="text-xl font-bold mb-4">AI Recommended Goal</h3>
            <p className="text-navy-400 text-sm mb-6 leading-relaxed">
              Based on the family's lower activity levels on weekends, the AI recommends a "Sunday Family Walk" challenge.
            </p>
            <button className="flex items-center space-x-2 text-brand-400 font-bold hover:text-brand-300 transition-colors">
              <span>Accept Challenge</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>
          
          <div className="grid grid-cols-2 gap-4">
            <button className="p-6 bg-white rounded-[2rem] border border-navy-100 shadow-sm hover:shadow-md transition-all text-left group">
              <div className="w-10 h-10 bg-indigo-50 text-indigo-500 rounded-xl flex items-center justify-center mb-4 group-hover:bg-indigo-500 group-hover:text-white transition-all">
                <Calendar className="w-5 h-5" />
              </div>
              <p className="font-bold text-navy-900 text-sm">Schedule Checkup</p>
            </button>
            <button className="p-6 bg-white rounded-[2rem] border border-navy-100 shadow-sm hover:shadow-md transition-all text-left group">
              <div className="w-10 h-10 bg-orange-50 text-orange-500 rounded-xl flex items-center justify-center mb-4 group-hover:bg-orange-500 group-hover:text-white transition-all">
                <TrendingUp className="w-5 h-5" />
              </div>
              <p className="font-bold text-navy-900 text-sm">Compare Groups</p>
            </button>
          </div>
        </div>

        <VoiceInterface />
      </div>
    </div>
  );
}
