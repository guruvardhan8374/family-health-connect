import { useState, useEffect } from 'react';
import { ShieldAlert, Phone, MapPin, AlertTriangle, Loader2, CheckCircle, Siren, Navigation, Building2 } from 'lucide-react';
import api from '../utils/api';
import { useSyncEvent } from '../contexts/SyncContext';

export default function Emergency() {
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [incomingAlerts, setIncomingAlerts] = useState([]);
  const [policeStations, setPoliceStations] = useState([]);
  const [fetchingPolice, setFetchingPolice] = useState(true);
  const [locationSharing, setLocationSharing] = useState(true);

  // Fetch nearby police stations dynamically based on location
  const fetchNearbyPolice = (lat = 12.9716, lng = 77.5946) => {
    setFetchingPolice(true);
    api.get(`/emergency/nearby-police/?lat=${lat}&lng=${lng}`)
      .then((res) => {
        setPoliceStations(res.data.police_stations || []);
      })
      .catch((err) => {
        console.error('Failed to fetch nearby police stations:', err);
      })
      .finally(() => setFetchingPolice(false));
  };

  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          fetchNearbyPolice(pos.coords.latitude, pos.coords.longitude);
        },
        () => {
          fetchNearbyPolice(); // fallback
        },
        { timeout: 5000 }
      );
    } else {
      fetchNearbyPolice();
    }
  }, []);

  const handleSOS = async () => {
    setLoading(true);
    setSuccess(false);
    
    const triggerSOSAlert = async (latitude = null, longitude = null) => {
      try {
        await api.post('/emergency/alerts/trigger/', {
          latitude,
          longitude,
          message: "Emergency SOS triggered with live location sharing!"
        });
        setSuccess(true);
        setTimeout(() => setSuccess(false), 5000);
      } catch (err) {
        console.error('SOS failed:', err);
      } finally {
        setLoading(false);
      }
    };

    if (navigator.geolocation && locationSharing) {
      navigator.geolocation.getCurrentPosition(
        async (pos) => {
          await triggerSOSAlert(pos.coords.latitude, pos.coords.longitude);
        },
        async (err) => {
          console.warn("Geolocation failed/blocked. Triggering SOS without location:", err);
          await triggerSOSAlert(null, null);
        },
        { timeout: 5000 }
      );
    } else {
      await triggerSOSAlert(null, null);
    }
  };

  // ── Receive SOS alerts from family members' mobile apps ───────────────────
  useSyncEvent('emergency.alert', (event) => {
    const alert = {
      id: event.data?.id || Date.now(),
      message: event.data?.message || 'Emergency! A family member needs help.',
      triggeredBy: event.data?.triggered_by || 'Family Member',
      location: event.data?.location_lat
        ? `${event.data.location_lat.toFixed(4)}, ${event.data.location_lng.toFixed(4)}`
        : 'Location unavailable',
      time: new Date().toLocaleTimeString(),
    };
    setIncomingAlerts((prev) => [alert, ...prev.slice(0, 4)]);
  }, []);

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-navy-900 tracking-tight">Emergency Assistance Protocol</h1>
        <p className="text-navy-500 mt-1">Locate nearby police control stations and instantly alert family.</p>
      </header>

      {/* Live incoming SOS alerts from mobile */}
      {incomingAlerts.length > 0 && (
        <div className="space-y-3">
          {incomingAlerts.map((alert) => (
            <div key={alert.id} className="flex items-start gap-4 bg-red-600 text-white p-5 rounded-3xl shadow-xl shadow-red-600/30 animate-slide-in">
              <div className="w-10 h-10 bg-white/20 rounded-2xl flex items-center justify-center shrink-0">
                <Siren className="w-5 h-5 animate-pulse" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-bold text-lg">🚨 SOS from {alert.triggeredBy}</p>
                <p className="text-red-100 text-sm mt-0.5">{alert.message}</p>
                <div className="flex flex-wrap gap-4 mt-2 text-xs text-red-200">
                  <span>📍 {alert.location}</span>
                  <span>⏰ {alert.time}</span>
                </div>
              </div>
              <button
                onClick={() => setIncomingAlerts((prev) => prev.filter((a) => a.id !== alert.id))}
                className="text-red-200 hover:text-white text-xs font-bold shrink-0 mt-1"
              >
                Dismiss
              </button>
            </div>
          ))}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Main SOS Trigger */}
        <div className="lg:col-span-1 bg-red-50 p-8 rounded-3xl border border-red-100 text-center flex flex-col items-center justify-center relative overflow-hidden">
          {loading && <div className="absolute top-0 left-0 w-full h-1 bg-red-500 animate-pulse"></div>}
          <div className="w-24 h-24 bg-white rounded-full flex items-center justify-center mb-6 shadow-lg shadow-red-500/20">
            {success ? <CheckCircle className="w-12 h-12 text-emerald-500" /> : <ShieldAlert className="w-12 h-12 text-red-500" />}
          </div>
          <h2 className="text-2xl font-bold text-red-900 mb-2">{success ? 'SOS Sent!' : 'Activate SOS'}</h2>
          <p className="text-red-700/80 mb-8 max-w-sm text-sm">
            {success 
              ? 'Your family has been notified and your live location is being shared.' 
              : 'Pressing this button will instantly alert all family members via WebSockets & FCM and share your live GPS position.'}
          </p>
          <button 
            onClick={handleSOS}
            disabled={loading || success}
            className={`w-full text-lg font-bold py-4 rounded-2xl transition-all hover:scale-105 shadow-xl flex items-center justify-center ${
              success 
                ? 'bg-emerald-500 text-white cursor-default' 
                : 'bg-red-500 text-white hover:bg-red-600 shadow-red-500/30'
            }`}
          >
            {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : success ? 'ALERT ACTIVE' : 'PRESS TO SEND SOS'}
          </button>
        </div>

        {/* Nearby Police Stations */}
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-white p-6 rounded-3xl border border-navy-100 shadow-sm">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-bold text-navy-900 flex items-center">
                <Building2 className="w-5 h-5 text-blue-600 mr-2" />
                Nearby Police Stations
              </h3>
              <span className="text-xs font-semibold text-blue-600 bg-blue-50 px-3 py-1 rounded-full">
                Sorted by Distance
              </span>
            </div>

            {fetchingPolice ? (
              <div className="p-8 text-center text-navy-400 flex items-center justify-center space-x-2">
                <Loader2 className="w-5 h-5 animate-spin text-blue-500" />
                <span className="text-sm">Locating nearest police control stations...</span>
              </div>
            ) : policeStations.length === 0 ? (
              <p className="text-navy-500 text-sm p-4 text-center">No police stations found nearby.</p>
            ) : (
              <div className="space-y-4">
                {policeStations.map((station) => (
                  <div key={station.id} className="p-4 bg-navy-50/70 rounded-2xl border border-navy-100 hover:border-blue-200 transition-all flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                    <div className="space-y-1">
                      <div className="flex items-center space-x-2">
                        <span className="font-bold text-navy-900">{station.name}</span>
                        <span className="text-xs bg-navy-200 text-navy-700 px-2 py-0.5 rounded-md font-bold">
                          {station.distance_formatted}
                        </span>
                      </div>
                      <p className="text-xs text-navy-500">{station.address}</p>
                      <p className="text-[11px] text-blue-600 font-semibold">
                        🚘 Est. Travel: {station.estimated_travel_time}
                      </p>
                    </div>

                    <div className="flex items-center space-x-2 shrink-0">
                      <a
                        href={`tel:${station.phone_number || '100'}`}
                        className="flex items-center space-x-1.5 bg-emerald-500 hover:bg-emerald-600 text-white px-4 py-2 rounded-xl text-xs font-bold transition-all shadow-sm"
                      >
                        <Phone className="w-3.5 h-3.5" />
                        <span>Call ({station.phone_number || '100'})</span>
                      </a>
                      <a
                        href={station.google_maps_link}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center space-x-1.5 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-xl text-xs font-bold transition-all shadow-sm"
                      >
                        <Navigation className="w-3.5 h-3.5" />
                        <span>Navigate</span>
                      </a>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-white p-6 rounded-3xl border border-navy-100 shadow-sm">
              <h3 className="text-lg font-bold text-navy-900 mb-2 flex items-center">
                <AlertTriangle className="w-5 h-5 text-orange-500 mr-2" />
                Active SOS Status
              </h3>
              {incomingAlerts.length === 0 ? (
                <p className="text-navy-500 text-sm">No active SOS alerts in your family circle.</p>
              ) : (
                <p className="text-red-600 text-sm font-bold">{incomingAlerts.length} active emergency alert(s) active.</p>
              )}
            </div>

            <div className="bg-white p-6 rounded-3xl border border-navy-100 shadow-sm">
              <h3 className="text-lg font-bold text-navy-900 mb-2 flex items-center">
                <MapPin className="w-5 h-5 text-purple-500 mr-2" />
                Live Location Sharing
              </h3>
              <div className="flex items-center justify-between">
                <p className="text-xs text-navy-500">Attach GPS position when triggering SOS</p>
                <button
                  onClick={() => setLocationSharing(!locationSharing)}
                  className={`w-11 h-6 rounded-full relative transition-colors ${
                    locationSharing ? 'bg-brand-500' : 'bg-navy-200'
                  }`}
                >
                  <div className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${
                    locationSharing ? 'right-1' : 'left-1'
                  }`}></div>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

