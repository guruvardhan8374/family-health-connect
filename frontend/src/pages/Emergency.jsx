import { useState } from 'react';
import { ShieldAlert, Phone, MapPin, AlertTriangle, Loader2, CheckCircle } from 'lucide-react';
import api from '../utils/api';

export default function Emergency() {
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const handleSOS = async () => {
    setLoading(true);
    setSuccess(false);
    
    try {
      // Get current location
      navigator.geolocation.getCurrentPosition(async (pos) => {
        const { latitude, longitude } = pos.coords;
        
        // 1. Trigger Django API (This will notify family members on backend)
        await api.post('/emergency/alerts/trigger/', {
          latitude,
          longitude
        });

        setSuccess(true);
        setTimeout(() => setSuccess(false), 5000);
      });
    } catch (err) {
      console.error('SOS failed:', err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-navy-900 tracking-tight">Emergency Protocol</h1>
        <p className="text-navy-500 mt-1">Configure SOS settings and emergency contacts.</p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-red-50 p-8 rounded-3xl border border-red-100 text-center flex flex-col items-center justify-center relative overflow-hidden">
          {loading && <div className="absolute top-0 left-0 w-full h-1 bg-red-500 animate-pulse"></div>}
          <div className="w-24 h-24 bg-white rounded-full flex items-center justify-center mb-6 shadow-lg shadow-red-500/20">
            {success ? <CheckCircle className="w-12 h-12 text-emerald-500" /> : <ShieldAlert className="w-12 h-12 text-red-500" />}
          </div>
          <h2 className="text-2xl font-bold text-red-900 mb-2">{success ? 'SOS Sent!' : 'Activate SOS'}</h2>
          <p className="text-red-700/80 mb-8 max-w-sm">
            {success 
              ? 'Your family has been notified and your live location is being shared.' 
              : 'Pressing this button will instantly alert all family members, share your live location, and contact local emergency services if configured.'}
          </p>
          <button 
            onClick={handleSOS}
            disabled={loading || success}
            className={`text-xl font-bold px-12 py-4 rounded-full transition-all hover:scale-105 shadow-xl flex items-center justify-center ${
              success 
                ? 'bg-emerald-500 text-white cursor-default' 
                : 'bg-red-500 text-white hover:bg-red-600 shadow-red-500/30'
            }`}
          >
            {loading ? <Loader2 className="w-8 h-8 animate-spin" /> : success ? 'ALERT ACTIVE' : 'PRESS TO SEND SOS'}
          </button>
        </div>

        <div className="space-y-6">
          <div className="bg-white p-6 rounded-3xl border border-navy-100 shadow-sm">
            <h3 className="text-lg font-bold text-navy-900 mb-4 flex items-center">
              <AlertTriangle className="w-5 h-5 text-orange-500 mr-2" />
              Active Alerts
            </h3>
            <p className="text-navy-500 text-sm">No active alerts at the moment.</p>
          </div>

          <div className="bg-white p-6 rounded-3xl border border-navy-100 shadow-sm">
            <h3 className="text-lg font-bold text-navy-900 mb-4 flex items-center">
              <Phone className="w-5 h-5 text-blue-500 mr-2" />
              Emergency Contacts
            </h3>
            <div className="space-y-3">
              <div className="flex justify-between items-center p-3 bg-navy-50 rounded-xl">
                <div>
                  <p className="font-semibold text-navy-900">Primary Care Physician</p>
                  <p className="text-sm text-navy-500">Dr. Smith</p>
                </div>
                <button className="text-brand-600 hover:text-brand-700 font-medium text-sm">Call</button>
              </div>
              <div className="flex justify-between items-center p-3 bg-navy-50 rounded-xl">
                <div>
                  <p className="font-semibold text-navy-900">Local Hospital</p>
                  <p className="text-sm text-navy-500">City General</p>
                </div>
                <button className="text-brand-600 hover:text-brand-700 font-medium text-sm">Call</button>
              </div>
            </div>
            <button className="mt-4 w-full py-2 border-2 border-dashed border-navy-200 text-navy-500 rounded-xl hover:bg-navy-50 hover:border-navy-300 transition-colors font-medium text-sm">
              + Add Contact
            </button>
          </div>

          <div className="bg-white p-6 rounded-3xl border border-navy-100 shadow-sm">
            <h3 className="text-lg font-bold text-navy-900 mb-4 flex items-center">
              <MapPin className="w-5 h-5 text-purple-500 mr-2" />
              Location Sharing
            </h3>
            <div className="flex items-center justify-between">
              <p className="text-sm text-navy-500">Share live location with family during SOS</p>
              <div className="w-11 h-6 bg-brand-500 rounded-full relative cursor-pointer">
                <div className="absolute right-1 top-1 w-4 h-4 bg-white rounded-full"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
