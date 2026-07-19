import { useState, useEffect, useCallback } from 'react';
import api from '../utils/api';
import { useSyncEvent } from '../contexts/SyncContext';
import useHealthWebSocket from '../hooks/useHealthWebSocket';
import CircularProgress from '../components/CircularProgress';
import { 
  Activity, Heart, Droplets, Moon, Flame, Wind, 
  Brain, Zap, Plus, ArrowUpRight, ArrowDownRight,
  ChevronRight, Calendar, RefreshCw, AlertTriangle, User,
  PlusCircle
} from 'lucide-react';
import { 
  AreaChart, Area, XAxis, YAxis, CartesianGrid, 
  Tooltip, ResponsiveContainer, BarChart, Bar, Cell
} from 'recharts';

export default function HealthHub() {
  const [timeRange, setTimeRange] = useState('Daily');
  const [familyData, setFamilyData] = useState([]);
  const [selectedMemberId, setSelectedMemberId] = useState(null);
  const [syncFlash, setSyncFlash] = useState(false);
  const [summaryData, setSummaryData] = useState(null);
  const [alerts, setAlerts] = useState([]);
  const [showGoalModal, setShowGoalModal] = useState(false);

  // New Fitness Summary & Log Modal States
  const [todaySummary, setTodaySummary] = useState({ steps: 0, distance: 0.0, heart_rate: null, blood_pressure: null });
  const [showLogModal, setShowLogModal] = useState(false);
  const [hrInput, setHrInput] = useState('');
  const [bpSysInput, setBpSysInput] = useState('');
  const [bpDiaInput, setBpDiaInput] = useState('');
  const [weightInput, setWeightInput] = useState('');
  const [logSaving, setLogSaving] = useState(false);

  // Goal Form Fields
  const [stepsGoal, setStepsGoal] = useState(10000);
  const [caloriesGoal, setCaloriesGoal] = useState(2000);
  const [hydrationGoal, setHydrationGoal] = useState(2.0);
  const [sleepGoal, setSleepGoal] = useState(8.0);
  const [distanceGoal, setDistanceGoal] = useState(5.0);

  const fetchFamilySummary = useCallback(async () => {
    try {
      const res = await api.get('/health/family-summary/');
      setFamilyData(res.data || []);
      // If no member is selected, select the current user by default if found
      if (res.data && res.data.length > 0 && !selectedMemberId) {
        setSelectedMemberId(res.data[0].user_id);
      }
    } catch (err) {
      console.error('Failed to fetch family health summary:', err);
    }
  }, [selectedMemberId]);

  const fetchTodaySummary = useCallback(async () => {
    try {
      const res = await api.get('/health/summary/today/');
      setTodaySummary(res.data || { steps: 0, distance: 0.0, heart_rate: null, blood_pressure: null });
    } catch (err) {
      console.error('Failed to fetch today\'s health summary:', err);
    }
  }, []);

  const fetchHealthSummary = useCallback(async () => {
    try {
      const res = await api.get(`/health/summary/?range=${timeRange}`);
      setSummaryData(res.data);
      if (res.data?.goal) {
        setStepsGoal(res.data.goal.steps_goal);
        setCaloriesGoal(res.data.goal.calories_goal);
        setHydrationGoal(res.data.goal.hydration_goal);
        setSleepGoal(res.data.goal.sleep_goal);
        setDistanceGoal(res.data.goal.distance_goal);
      }
      if (res.data?.active_alerts) {
        setAlerts(res.data.active_alerts);
      }
    } catch (err) {
      console.error('Failed to fetch health summary:', err);
    }
  }, [timeRange]);

  useEffect(() => {
    fetchFamilySummary();
  }, [fetchFamilySummary]);

  useEffect(() => {
    fetchHealthSummary();
  }, [fetchHealthSummary]);

  useEffect(() => {
    fetchTodaySummary();
    const interval = setInterval(fetchTodaySummary, 20000);
    return () => clearInterval(interval);
  }, [fetchTodaySummary]);

  // Real-time synchronization
  const currentUserId = parseInt(localStorage.getItem('user_id') || '0');

  const handleVitalsUpdate = useCallback((snapshot) => {
    if (!snapshot) return;
    setSyncFlash(true);
    setTimeout(() => setSyncFlash(false), 2500);

    // Update familyData locally for the user who updated
    setFamilyData(prev => prev.map(member => {
      const matchId = snapshot.user_id || snapshot.user;
      if (member.user_id === matchId || (!matchId && member.user_id === currentUserId)) {
        return {
          ...member,
          latest_snapshot: snapshot
        };
      }
      return member;
    }));

    // If it's for the current user, update summaryData metrics instantly
    const matchId = snapshot.user_id || snapshot.user;
    if (matchId === currentUserId || !matchId) {
      setSummaryData(prev => {
        if (!prev) return prev;
        return {
          ...prev,
          latest_heart_rate: snapshot.heart_rate ?? prev.latest_heart_rate,
          today_steps: snapshot.steps ?? prev.today_steps,
          latest_spo2: snapshot.spo2 ?? prev.latest_spo2,
          today_sleep: snapshot.sleep_hours ?? prev.today_sleep,
          today_calories: snapshot.calories ?? prev.today_calories,
          today_hydration: snapshot.hydration ?? prev.today_hydration,
          latest_bmi: snapshot.bmi ?? prev.latest_bmi,
          today_distance: snapshot.distance ?? prev.today_distance,
        };
      });
    }
  }, [currentUserId]);

  const handleAlertUpdate = useCallback((newAlerts) => {
    setAlerts(newAlerts);
  }, []);

  useHealthWebSocket(handleVitalsUpdate, handleAlertUpdate);

  // Sync event from sync context
  useSyncEvent('health.update', (event) => {
    if (event && event.data) {
      handleVitalsUpdate(event.data);
    }
  }, [handleVitalsUpdate]);

  // Save Goal changes
  const handleSaveGoals = async (e) => {
    e.preventDefault();
    try {
      await api.post('/health/goals/', {
        steps_goal: stepsGoal,
        calories_goal: caloriesGoal,
        hydration_goal: hydrationGoal,
        sleep_goal: sleepGoal,
        distance_goal: distanceGoal,
      });
      setShowGoalModal(false);
      fetchHealthSummary();
    } catch (err) {
      console.error('Failed to update goals:', err);
    }
  };

  const handleLogVitals = async (e) => {
    e.preventDefault();
    setLogSaving(true);
    try {
      const promises = [];
      if (hrInput) {
        promises.push(api.post('/health/metrics/', { metric_type: 'HEART_RATE', value: parseFloat(hrInput) }));
      }
      if (bpSysInput) {
        promises.push(api.post('/health/metrics/', { metric_type: 'BLOOD_PRESSURE_SYSTOLIC', value: parseFloat(bpSysInput) }));
      }
      if (bpDiaInput) {
        promises.push(api.post('/health/metrics/', { metric_type: 'BLOOD_PRESSURE_DIASTOLIC', value: parseFloat(bpDiaInput) }));
      }
      if (weightInput) {
        promises.push(api.post('/health/metrics/', { metric_type: 'WEIGHT', value: parseFloat(weightInput) }));
      }
      if (promises.length > 0) {
        await Promise.all(promises);
        setHrInput('');
        setBpSysInput('');
        setBpDiaInput('');
        setWeightInput('');
        fetchTodaySummary();
      }
      setShowLogModal(false);
    } catch (err) {
      console.error('Failed to log vitals metrics:', err);
    } finally {
      setLogSaving(false);
    }
  };

  const selectedMemberData = familyData.find(m => m.user_id === selectedMemberId);

  // Compute selected member vitals
  const displayVitals = selectedMemberData?.latest_snapshot || {};
  const currentUserId = parseInt(localStorage.getItem('user_id') || '0');
  const isSelf = selectedMemberId === currentUserId;

  // Use summaryData/todaySummary for self, otherwise use family snapshot metrics
  const activeVitals = {
    heartRate: isSelf ? (todaySummary.heart_rate ?? summaryData?.latest_heart_rate ?? displayVitals.heart_rate ?? '--') : (displayVitals.heart_rate ?? '--'),
    steps: isSelf ? (todaySummary.steps ?? summaryData?.today_steps ?? displayVitals.steps ?? 0) : (displayVitals.steps ?? 0),
    oxygen: isSelf ? (summaryData?.latest_spo2 ?? displayVitals.spo2 ?? '--') : (displayVitals.spo2 ?? '--'),
    sleep: isSelf ? (summaryData?.today_sleep ?? displayVitals.sleep_session ?? displayVitals.sleep_hours ?? '--') : (displayVitals.sleep_hours ?? '--'),
    calories: isSelf ? (summaryData?.today_calories ?? displayVitals.calories ?? 0) : (displayVitals.calories ?? 0),
    hydration: isSelf ? (summaryData?.today_hydration ?? displayVitals.hydration ?? '--') : (displayVitals.hydration ?? '--'),
    bmi: isSelf ? (summaryData?.latest_bmi ?? displayVitals.bmi ?? '--') : (displayVitals.bmi ?? '--'),
    distance: isSelf ? (todaySummary.distance ?? summaryData?.today_distance ?? displayVitals.distance ?? '--') : (displayVitals.distance ?? '--'),
    bloodPressure: isSelf ? (todaySummary.blood_pressure ?? displayVitals.blood_pressure ?? '--') : (displayVitals.blood_pressure ?? '--'),
  };

  // Convert chart details
  const heartRateChartData = summaryData?.heart_rate?.map((hr, idx) => ({
    time: summaryData.labels[idx] || '',
    heart: hr || 70,
  })) || [];

  const stepsChartData = summaryData?.steps?.map((st, idx) => ({
    label: summaryData.labels[idx] || '',
    steps: st || 0,
  })) || [];

  const activeAlerts = alerts.filter(a => !a.is_read);

  const markAllAlertsRead = async () => {
    try {
      await api.post('/health/alerts/mark-all-read/');
      setAlerts([]);
    } catch (err) {
      console.error('Failed to clear alerts:', err);
    }
  };

  return (
    <div className="space-y-8 pb-12">
      {/* Real-time Sync Banner */}
      {syncFlash && (
        <div className="fixed top-20 right-6 z-50 flex items-center gap-2 bg-emerald-500 text-white px-5 py-3 rounded-2xl shadow-xl animate-bounce">
          <RefreshCw className="w-4 h-4 animate-spin" />
          <span className="text-sm font-bold">Health sync updated live!</span>
        </div>
      )}

      {/* Emergency Alert Banner */}
      {activeAlerts.length > 0 && (
        <div className="bg-red-500/10 border border-red-500/20 p-6 rounded-[2rem] text-red-200 flex flex-col md:flex-row items-center justify-between gap-4 animate-pulse">
          <div className="flex items-center space-x-3">
            <AlertTriangle className="w-8 h-8 text-red-500 shrink-0" />
            <div>
              <h4 className="font-bold text-red-400">Critical Vitals Warning</h4>
              <p className="text-sm text-red-300/80">{activeAlerts[0].message}</p>
            </div>
          </div>
          <button 
            onClick={markAllAlertsRead}
            className="px-6 py-2 bg-red-500 text-white font-bold rounded-xl text-xs hover:bg-red-600 transition"
          >
            Acknowledge & Dismiss
          </button>
        </div>
      )}

      {/* Header Section */}
      <header className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-bold text-navy-900 tracking-tight">Health Hub</h1>
          <p className="text-navy-500 mt-1">Real-time health insights and Google Fit synchronization.</p>
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
          
          <button 
            onClick={() => setShowGoalModal(true)}
            className="flex items-center space-x-1 px-4 py-2 bg-white border border-navy-100 rounded-2xl shadow-sm text-navy-600 hover:text-brand-500 hover:border-brand-200 transition-all font-bold text-sm"
          >
            <PlusCircle className="w-4 h-4" />
            <span>Set Goals</span>
          </button>

          <button 
            onClick={() => setShowLogModal(true)}
            className="flex items-center space-x-1 px-4 py-2 bg-brand-500 text-white rounded-2xl shadow-sm hover:bg-brand-600 transition-all font-bold text-sm"
          >
            <Plus className="w-4 h-4" />
            <span>Log Vitals</span>
          </button>
        </div>
      </header>

      {/* Family Member Switcher */}
      <div className="flex space-x-4 overflow-x-auto pb-2 scrollbar-hide">
        {familyData.map((member) => (
          <button
            key={member.user_id}
            onClick={() => setSelectedMemberId(member.user_id)}
            className={`flex items-center space-x-3 px-5 py-3 rounded-2xl border transition-all shrink-0 ${
              selectedMemberId === member.user_id
                ? 'bg-brand-50 border-brand-200 shadow-sm' 
                : 'bg-white border-navy-100 hover:border-brand-200'
            }`}
          >
            <div className="w-10 h-10 rounded-full bg-brand-100 text-brand-600 flex items-center justify-center font-bold">
              <User className="w-5 h-5" />
            </div>
            <div className="text-left">
              <p className={`font-bold text-sm ${selectedMemberId === member.user_id ? 'text-brand-600' : 'text-navy-900'}`}>
                {member.username} {member.user_id === currentUserId && '(You)'}
              </p>
              <p className="text-navy-400 text-xs">{member.label}</p>
            </div>
          </button>
        ))}
      </div>

      {/* Main Google Fit-style Dashboard Vitals */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {/* Heart Rate Card */}
        <div className="bg-white/70 backdrop-blur-md p-6 rounded-[2rem] border border-navy-100 shadow-sm flex items-center justify-between group hover:shadow-xl transition-all duration-300">
          <div className="space-y-2">
            <div className="p-3 rounded-2xl bg-red-500/10 text-red-500 w-fit group-hover:scale-110 transition-transform">
              <Heart className="w-6 h-6" />
            </div>
            <p className="text-navy-500 text-sm font-medium">Heart Rate</p>
            <div className="flex items-baseline space-x-1">
              <h3 className="text-2xl font-bold text-navy-900">{activeVitals.heartRate}</h3>
              <span className="text-navy-400 text-sm font-medium">bpm</span>
            </div>
          </div>
          <CircularProgress 
            value={activeVitals.heartRate !== '--' ? Math.min((activeVitals.heartRate / 100) * 100, 100) : 0} 
            size={72} 
            stroke={6}
            color="#ef4444"
            label={activeVitals.heartRate.toString()}
            sublabel="bpm"
          />
        </div>

        {/* Steps Card */}
        <div className="bg-white/70 backdrop-blur-md p-6 rounded-[2rem] border border-navy-100 shadow-sm flex items-center justify-between group hover:shadow-xl transition-all duration-300">
          <div className="space-y-2">
            <div className="p-3 rounded-2xl bg-brand-500/10 text-brand-500 w-fit group-hover:scale-110 transition-transform">
              <Activity className="w-6 h-6" />
            </div>
            <p className="text-navy-500 text-sm font-medium">Daily Steps</p>
            <div className="flex items-baseline space-x-1">
              <h3 className="text-2xl font-bold text-navy-900">{activeVitals.steps.toLocaleString()}</h3>
              <span className="text-navy-400 text-sm font-medium">/ {stepsGoal.toLocaleString()}</span>
            </div>
          </div>
          <CircularProgress 
            value={stepsGoal > 0 ? Math.min((activeVitals.steps / stepsGoal) * 100, 100) : 0} 
            size={72} 
            stroke={6}
            color="#14b8a6"
            label={Math.round((activeVitals.steps / stepsGoal) * 100 || 0).toString() + '%'}
          />
        </div>

        {/* Blood Oxygen */}
        <div className="bg-white/70 backdrop-blur-md p-6 rounded-[2rem] border border-navy-100 shadow-sm flex items-center justify-between group hover:shadow-xl transition-all duration-300">
          <div className="space-y-2">
            <div className="p-3 rounded-2xl bg-blue-500/10 text-blue-500 w-fit group-hover:scale-110 transition-transform">
              <Wind className="w-6 h-6" />
            </div>
            <p className="text-navy-500 text-sm font-medium">Oxygen (SpO₂)</p>
            <div className="flex items-baseline space-x-1">
              <h3 className="text-2xl font-bold text-navy-900">{activeVitals.oxygen}</h3>
              <span className="text-navy-400 text-sm font-medium">%</span>
            </div>
          </div>
          <CircularProgress 
            value={activeVitals.oxygen !== '--' ? activeVitals.oxygen : 0} 
            size={72} 
            stroke={6}
            color="#3b82f6"
            label={activeVitals.oxygen.toString() + '%'}
          />
        </div>

        {/* Sleep Duration */}
        <div className="bg-white/70 backdrop-blur-md p-6 rounded-[2rem] border border-navy-100 shadow-sm flex items-center justify-between group hover:shadow-xl transition-all duration-300">
          <div className="space-y-2">
            <div className="p-3 rounded-2xl bg-indigo-500/10 text-indigo-500 w-fit group-hover:scale-110 transition-transform">
              <Moon className="w-6 h-6" />
            </div>
            <p className="text-navy-500 text-sm font-medium">Sleep hours</p>
            <div className="flex items-baseline space-x-1">
              <h3 className="text-2xl font-bold text-navy-900">{activeVitals.sleep}</h3>
              <span className="text-navy-400 text-sm font-medium">hrs</span>
            </div>
          </div>
          <CircularProgress 
            value={sleepGoal > 0 && activeVitals.sleep !== '--' ? Math.min((activeVitals.sleep / sleepGoal) * 100, 100) : 0} 
            size={72} 
            stroke={6}
            color="#6366f1"
            label={activeVitals.sleep.toString()}
          />
        </div>
      </div>

      {/* Other Metrics (Calories, Hydration, Weight/BMI, Distance) */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-[2rem] border border-navy-100 shadow-sm flex items-center space-x-4">
          <div className="p-3 rounded-2xl bg-orange-500/10 text-orange-500">
            <Flame className="w-5 h-5" />
          </div>
          <div>
            <p className="text-navy-400 text-xs">Calories Burned</p>
            <p className="text-lg font-bold text-navy-900">{activeVitals.calories.toLocaleString()} kcal</p>
            <p className="text-navy-400 text-xs">Goal: {caloriesGoal} kcal</p>
          </div>
        </div>

        <div className="bg-white p-6 rounded-[2rem] border border-navy-100 shadow-sm flex items-center space-x-4">
          <div className="p-3 rounded-2xl bg-cyan-500/10 text-cyan-500">
            <Droplets className="w-5 h-5" />
          </div>
          <div>
            <p className="text-navy-400 text-xs">Hydration</p>
            <p className="text-lg font-bold text-navy-900">{activeVitals.hydration} L</p>
            <p className="text-navy-400 text-xs">Goal: {hydrationGoal} L</p>
          </div>
        </div>

        <div className="bg-white p-6 rounded-[2rem] border border-navy-100 shadow-sm flex items-center space-x-4">
          <div className="p-3 rounded-2xl bg-purple-500/10 text-purple-500">
            <Brain className="w-5 h-5" />
          </div>
          <div>
            <p className="text-navy-400 text-xs">BMI & Weight</p>
            <p className="text-lg font-bold text-navy-900">{activeVitals.bmi} BMI</p>
            <p className="text-navy-400 text-xs">Weight: {selectedMemberData?.latest_snapshot?.weight || '--'} kg</p>
          </div>
        </div>

        <div className="bg-white p-6 rounded-[2rem] border border-navy-100 shadow-sm flex items-center space-x-4">
          <div className="p-3 rounded-2xl bg-pink-500/10 text-pink-500">
            <Zap className="w-5 h-5" />
          </div>
          <div>
            <p className="text-navy-400 text-xs">Distance Today</p>
            <p className="text-lg font-bold text-navy-900">{activeVitals.distance} km</p>
            <p className="text-navy-400 text-xs">Goal: {distanceGoal} km</p>
          </div>
        </div>
      </div>

      {/* Real-time Charts Section (Only active/available for self due to summary detail) */}
      {isSelf && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Heart Rate Area Chart */}
          <div className="bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-sm">
            <div className="flex items-center justify-between mb-8">
              <div>
                <h3 className="text-xl font-bold text-navy-900">Heart Rate Trends</h3>
                <p className="text-navy-500 text-sm">Real-time dynamic heart rate tracking ({timeRange})</p>
              </div>
            </div>
            
            <div className="h-72 w-full">
              {heartRateChartData.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={heartRateChartData}>
                    <defs>
                      <linearGradient id="heartGradient" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3}/>
                        <stop offset="95%" stopColor="#ef4444" stopOpacity={0}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                    <XAxis dataKey="time" axisLine={false} tickLine={false} tick={{fill: '#64748b', fontSize: 12}} dy={10} />
                    <YAxis domain={['auto', 'auto']} axisLine={false} tickLine={false} tick={{fill: '#64748b', fontSize: 12}} dx={-10} />
                    <Tooltip 
                      contentStyle={{ borderRadius: '20px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)', padding: '12px' }}
                      itemStyle={{ fontWeight: 'bold' }}
                    />
                    <Area type="monotone" dataKey="heart" stroke="#ef4444" strokeWidth={4} fillOpacity={1} fill="url(#heartGradient)" />
                  </AreaChart>
                </ResponsiveContainer>
              ) : (
                <div className="h-full flex items-center justify-center text-navy-400 text-sm">
                  No chart data available for this range.
                </div>
              )}
            </div>
          </div>

          {/* Steps Bar Chart */}
          <div className="bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-sm">
            <div className="flex items-center justify-between mb-8">
              <div>
                <h3 className="text-xl font-bold text-navy-900">Activity Overview</h3>
                <p className="text-navy-500 text-sm">Daily steps aggregated ({timeRange})</p>
              </div>
            </div>
            
            <div className="h-72 w-full">
              {stepsChartData.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={stepsChartData}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                    <XAxis dataKey="label" axisLine={false} tickLine={false} tick={{fill: '#64748b', fontSize: 12}} dy={10} />
                    <YAxis axisLine={false} tickLine={false} tick={{fill: '#64748b', fontSize: 12}} dx={-10} />
                    <Tooltip 
                      cursor={{fill: '#f8fafc'}}
                      contentStyle={{ borderRadius: '20px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)', padding: '12px' }}
                    />
                    <Bar dataKey="steps" radius={[10, 10, 0, 0]}>
                      {stepsChartData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={index === stepsChartData.length - 1 ? '#14b8a6' : '#ccfbf1'} />
                      ))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              ) : (
                <div className="h-full flex items-center justify-center text-navy-400 text-sm">
                  No activity logs found for this range.
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Goal Modal */}
      {showGoalModal && (
        <div className="fixed inset-0 bg-navy-900/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-[2.5rem] max-w-md w-full p-8 shadow-2xl border border-navy-100 animate-slide-in">
            <h3 className="text-2xl font-bold text-navy-900 mb-6">Edit Daily Health Goals</h3>
            <form onSubmit={handleSaveGoals} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-navy-600 mb-1">Steps Target</label>
                <input 
                  type="number"
                  value={stepsGoal}
                  onChange={(e) => setStepsGoal(parseInt(e.target.value))}
                  className="w-full px-4 py-3 rounded-2xl border border-navy-100 focus:outline-none focus:border-brand-500 text-navy-900 font-bold"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-navy-600 mb-1">Calories Burned Target (kcal)</label>
                <input 
                  type="number"
                  value={caloriesGoal}
                  onChange={(e) => setCaloriesGoal(parseInt(e.target.value))}
                  className="w-full px-4 py-3 rounded-2xl border border-navy-100 focus:outline-none focus:border-brand-500 text-navy-900 font-bold"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-navy-600 mb-1">Hydration Target (L)</label>
                <input 
                  type="number"
                  step="0.1"
                  value={hydrationGoal}
                  onChange={(e) => setHydrationGoal(parseFloat(e.target.value))}
                  className="w-full px-4 py-3 rounded-2xl border border-navy-100 focus:outline-none focus:border-brand-500 text-navy-900 font-bold"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-navy-600 mb-1">Sleep Target (hrs)</label>
                <input 
                  type="number"
                  step="0.5"
                  value={sleepGoal}
                  onChange={(e) => setSleepGoal(parseFloat(e.target.value))}
                  className="w-full px-4 py-3 rounded-2xl border border-navy-100 focus:outline-none focus:border-brand-500 text-navy-900 font-bold"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-navy-600 mb-1">Distance Target (km)</label>
                <input 
                  type="number"
                  step="0.1"
                  value={distanceGoal}
                  onChange={(e) => setDistanceGoal(parseFloat(e.target.value))}
                  className="w-full px-4 py-3 rounded-2xl border border-navy-100 focus:outline-none focus:border-brand-500 text-navy-900 font-bold"
                />
              </div>

              <div className="flex space-x-3 pt-4">
                <button 
                  type="button" 
                  onClick={() => setShowGoalModal(false)}
                  className="w-1/2 py-3 bg-navy-50 text-navy-600 font-bold rounded-2xl hover:bg-navy-100 transition"
                >
                  Cancel
                </button>
                <button 
                  type="submit" 
                  className="w-1/2 py-3 bg-brand-500 text-white font-bold rounded-2xl hover:bg-brand-600 transition"
                >
                  Save Goals
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Log Vitals Modal */}
      {showLogModal && (
        <div className="fixed inset-0 bg-navy-900/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-[2.5rem] max-w-md w-full p-8 shadow-2xl border border-navy-100 animate-slide-in">
            <h3 className="text-2xl font-bold text-navy-900 mb-6">Log New Vitals Reading</h3>
            <form onSubmit={handleLogVitals} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-navy-600 mb-1">Heart Rate (bpm)</label>
                <input 
                  type="number"
                  placeholder="e.g. 72"
                  value={hrInput}
                  onChange={(e) => setHrInput(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl border border-navy-100 focus:outline-none focus:border-brand-500 text-navy-900 font-bold"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-navy-600 mb-1">BP Systolic (mmHg)</label>
                  <input 
                    type="number"
                    placeholder="e.g. 120"
                    value={bpSysInput}
                    onChange={(e) => setBpSysInput(e.target.value)}
                    className="w-full px-4 py-3 rounded-2xl border border-navy-100 focus:outline-none focus:border-brand-500 text-navy-900 font-bold"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-navy-600 mb-1">BP Diastolic (mmHg)</label>
                  <input 
                    type="number"
                    placeholder="e.g. 80"
                    value={bpDiaInput}
                    onChange={(e) => setBpDiaInput(e.target.value)}
                    className="w-full px-4 py-3 rounded-2xl border border-navy-100 focus:outline-none focus:border-brand-500 text-navy-900 font-bold"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-navy-600 mb-1">Weight (kg) — Optional</label>
                <input 
                  type="number"
                  step="0.1"
                  placeholder="e.g. 70.0"
                  value={weightInput}
                  onChange={(e) => setWeightInput(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl border border-navy-100 focus:outline-none focus:border-brand-500 text-navy-900 font-bold"
                />
              </div>

              <div className="flex space-x-3 pt-4">
                <button 
                  type="button" 
                  onClick={() => setShowLogModal(false)}
                  className="w-1/2 py-3 bg-navy-50 text-navy-600 font-bold rounded-2xl hover:bg-navy-100 transition"
                >
                  Cancel
                </button>
                <button 
                  type="submit" 
                  disabled={logSaving}
                  className="w-1/2 py-3 bg-brand-500 text-white font-bold rounded-2xl hover:bg-brand-600 transition flex items-center justify-center"
                >
                  {logSaving ? 'Saving...' : 'Log Vitals'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
