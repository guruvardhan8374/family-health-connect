import { useEffect, useState, useRef, useCallback } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import api from '../utils/api';
import { useSyncEvent } from '../contexts/SyncContext';

// Helper to create Leaflet custom markers with Profile Picture & Status Badge
const createCustomIcon = (avatarUrl, name, isOnline = true, isSelf = false) => {
  const initial = name ? name.charAt(0).toUpperCase() : '?';
  const ringColor = isSelf ? 'border-teal-500' : (isOnline ? 'border-emerald-500' : 'border-slate-400');
  const badgeColor = isSelf ? 'bg-teal-500' : (isOnline ? 'bg-emerald-500' : 'bg-slate-400');

  const avatarHtml = avatarUrl ? `
    <img src="${avatarUrl}" class="w-10 h-10 rounded-full object-cover" />
  ` : `
    <div class="w-10 h-10 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-800 dark:text-white flex items-center justify-center font-bold text-sm">
      ${initial}
    </div>
  `;

  return new L.DivIcon({
    html: `
      <div class="relative group cursor-pointer">
        <div class="w-11 h-11 rounded-full border-3 ${ringColor} shadow-lg bg-white overflow-hidden flex items-center justify-center">
          ${avatarHtml}
        </div>
        <div class="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 ${badgeColor} border-2 border-white rounded-full"></div>
      </div>
    `,
    className: 'custom-marker-icon',
    iconSize: [44, 44],
    iconAnchor: [22, 44],
    popupAnchor: [0, -44],
  });
};

function MapController({ center }) {
  const map = useMap();
  useEffect(() => {
    if (center && center[0] && center[1]) {
      map.setView(center, map.getZoom());
    }
  }, [center, map]);
  return null;
}

const defaultCenter = [12.9716, 77.5946]; // Fallback coordinates

// Haversine distance calculator in km
const calculateDistanceKm = (lat1, lon1, lat2, lon2) => {
  const p = 0.017453292519943295;
  const a = 0.5 - Math.cos((lat2 - lat1) * p) / 2 +
    Math.cos(lat1 * p) * Math.cos(lat2 * p) * (1 - Math.cos((lon2 - lon1) * p)) / 2;
  return 12.742 * Math.asin(Math.sqrt(a));
};

export default function FamilyMap() {
  const [familyMembers, setFamilyMembers] = useState([]);
  const [myLocation, setMyLocation] = useState(null);
  const [myUser, setMyUser] = useState(null);
  const lastPostTimeRef = useRef(0);

  // Fetch current user and family members on load
  const loadFamilyData = useCallback(async () => {
    try {
      const savedGroupId = localStorage.getItem('active_family_group_id');
      const query = savedGroupId ? `?group_id=${savedGroupId}` : '';
      const [userRes, membersRes] = await Promise.allSettled([
        api.get('/users/profile/'),
        api.get(`/family/members/${query}`),
      ]);

      if (userRes.status === 'fulfilled' && userRes.value.data) {
        setMyUser(userRes.value.data);
      }

      if (membersRes.status === 'fulfilled' && membersRes.value.data) {
        const list = Array.isArray(membersRes.value.data)
          ? membersRes.value.data
          : (membersRes.value.data.results || []);
        setFamilyMembers(list);
      }
    } catch (e) {
      console.error('Failed to load family map data:', e);
    }
  }, []);

  useEffect(() => {
    loadFamilyData();
  }, [loadFamilyData]);

  // Real-time WebSocket listener for location.update and family.update
  useSyncEvent('location.update', (event) => {
    const data = event.data;
    if (!data || !data.user_id) return;

    setFamilyMembers((prev) => {
      const copy = [...prev];
      const idx = copy.findIndex((m) => m.user === data.user_id || m.user_details?.id === data.user_id);
      if (idx !== -1) {
        copy[idx] = {
          ...copy[idx],
          latest_location: {
            latitude: data.latitude,
            longitude: data.longitude,
            speed: data.speed || 0,
            battery_level: data.battery_level || 100,
            timestamp: data.timestamp,
            is_online: (data.is_online ?? true) && (data.is_sharing_enabled !== false),
            is_sharing_enabled: data.is_sharing_enabled ?? true,
            last_seen_formatted: data.last_seen_formatted || 'Just now',
          },
        };
        return copy;
      } else {
        loadFamilyData();
        return prev;
      }
    });
  });

  useSyncEvent('family.update', () => {
    loadFamilyData();
  });

  // Watch browser Geolocation and post update to API every 8-10 seconds
  useEffect(() => {
    if (!navigator.geolocation) return;

    const watchId = navigator.geolocation.watchPosition(
      (position) => {
        const { latitude, longitude, speed } = position.coords;
        const newLoc = { lat: latitude, lng: longitude };
        setMyLocation(newLoc);

        const now = Date.now();
        if (now - lastPostTimeRef.current > 8000) {
          lastPostTimeRef.current = now;
          api.post('/users/locations/', {
            latitude,
            longitude,
            speed: speed ? Math.round(speed * 3.6) : 0,
            battery_level: 95,
            is_moving: (speed || 0) > 0.5,
          }).catch(() => {});
        }
      },
      (error) => console.warn('Geolocation access warning:', error.message),
      { enableHighAccuracy: true, maximumAge: 10000, timeout: 10000 }
    );

    return () => navigator.geolocation.clearWatch(watchId);
  }, []);

  const mapCenter = myLocation
    ? [myLocation.lat, myLocation.lng]
    : defaultCenter;

  return (
    <div className="h-[420px] w-full rounded-[2rem] overflow-hidden border border-slate-200 dark:border-slate-800 shadow-2xl relative z-0">
      <MapContainer center={mapCenter} zoom={14} style={{ height: '100%', width: '100%' }}>
        <TileLayer
          url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        />
        <MapController center={myLocation ? [myLocation.lat, myLocation.lng] : null} />

        {/* Current logged in user marker */}
        {myLocation && (
          <Marker
            position={[myLocation.lat, myLocation.lng]}
            icon={createCustomIcon(myUser?.profile_picture, myUser?.username || 'You', true, true)}
          >
            <Popup className="custom-popup">
              <div className="p-2 min-w-[140px]">
                <div className="flex items-center space-x-2">
                  <span className="w-2.5 h-2.5 rounded-full bg-teal-500 animate-pulse"></span>
                  <p className="font-bold text-slate-900 text-sm">You (Live)</p>
                </div>
                <p className="text-xs text-slate-500 mt-1">Sharing location</p>
              </div>
            </Popup>
          </Marker>
        )}

        {/* Family member markers */}
        {familyMembers.map((member) => {
          const loc = member.latest_location;
          if (!loc || !loc.latitude || !loc.longitude) return null;

          const user = member.user_details || {};
          // Skip drawing self if already rendered
          if (myUser && user.id === myUser.id) return null;

          const name = user.username || 'Family Member';
          const avatar = user.profile_picture;
          const isOnline = loc.is_online === true;
          const isSharing = loc.is_sharing_enabled !== false;
          const distance = myLocation
            ? calculateDistanceKm(myLocation.lat, myLocation.lng, loc.latitude, loc.longitude).toFixed(1)
            : null;

          return (
            <Marker
              key={member.id || user.id}
              position={[loc.latitude, loc.longitude]}
              icon={createCustomIcon(avatar, name, isOnline, false)}
            >
              <Popup>
                <div className="p-2 min-w-[170px] space-y-1">
                  <div className="flex items-center space-x-2">
                    <span className={`w-2.5 h-2.5 rounded-full ${isOnline ? 'bg-emerald-500' : 'bg-slate-400'}`}></span>
                    <p className="font-bold text-slate-900 text-sm">{name}</p>
                  </div>

                  <p className="text-xs text-slate-600 font-medium">
                    {isOnline
                      ? '● Live Online'
                      : (!isSharing ? '● Location Sharing Disabled' : `● ${loc.last_seen_formatted || 'Offline'}`)}
                  </p>

                  <div className="border-t border-slate-100 pt-1 mt-1 text-[11px] text-slate-500 space-y-0.5">
                    {distance !== null && <p><strong>Distance:</strong> {distance} km</p>}
                    <p><strong>Speed:</strong> {loc.speed || 0} km/h</p>
                    <p><strong>Battery:</strong> {loc.battery_level || 100}%</p>
                    <p><strong>Location Sharing:</strong> {isSharing ? 'Enabled' : 'Disabled'}</p>
                    {loc.last_seen_formatted && <p><strong>Updated:</strong> {loc.last_seen_formatted}</p>}
                  </div>
                </div>
              </Popup>
            </Marker>
          );
        })}
      </MapContainer>

      {/* Live Family Member Location Roster */}
      <div className="p-4 bg-slate-50 dark:bg-slate-900 border-t border-slate-200 dark:border-slate-800">
        <div className="flex items-center justify-between mb-3">
          <h4 className="text-xs font-black uppercase text-slate-400 tracking-wider">
            Circle Location Status ({familyMembers.length} {familyMembers.length === 1 ? 'member' : 'members'})
          </h4>
          <span className="text-[10px] font-bold text-emerald-600 bg-emerald-50 dark:bg-emerald-950/40 px-2 py-0.5 rounded-md">
            Live WebSockets Active
          </span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
          {familyMembers.length === 0 ? (
            <div className="col-span-full text-center py-4 text-xs text-slate-400 font-semibold">
              No family members found in this circle yet.
            </div>
          ) : (
            familyMembers.map((member) => {
              const user = member.user_details || {};
              const isSelf = myUser && user.id === myUser.id;
              const loc = member.latest_location;
              const isOnline = isSelf || loc?.is_online === true;
              const hasCoords = loc && loc.latitude && loc.longitude;
              const name = user.username || 'Family Member';
              const role = member.label || member.role || 'Member';

              return (
                <div
                  key={member.id || user.id}
                  className="bg-white dark:bg-slate-800 p-3 rounded-2xl border border-slate-200 dark:border-slate-700 shadow-sm flex items-center justify-between space-x-3"
                >
                  <div className="flex items-center space-x-3 min-w-0">
                    <div className="relative flex-shrink-0">
                      {user.profile_picture ? (
                        <img src={user.profile_picture} alt={name} className="w-9 h-9 rounded-full object-cover border-2 border-slate-200 dark:border-slate-700" />
                      ) : (
                        <div className="w-9 h-9 rounded-full bg-teal-50 dark:bg-teal-950 text-teal-600 font-bold flex items-center justify-center text-xs border-2 border-teal-200">
                          {name.charAt(0).toUpperCase()}
                        </div>
                      )}
                      <div className={`absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full border-2 border-white dark:border-slate-800 ${isOnline ? 'bg-emerald-500' : 'bg-slate-400'}`}></div>
                    </div>
                    <div className="min-w-0">
                      <p className="font-bold text-slate-900 dark:text-white text-xs truncate">
                        {name} {isSelf && '(You)'}
                      </p>
                      <p className="text-[10px] text-slate-400 font-medium uppercase truncate">{role}</p>
                    </div>
                  </div>

                  <div className="text-right flex-shrink-0">
                    {hasCoords ? (
                      <div>
                        <span className={`inline-block px-2 py-0.5 rounded-md text-[10px] font-bold ${isOnline ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-600'}`}>
                          {isOnline ? 'Live Online' : (loc.last_seen_formatted || 'Offline')}
                        </span>
                        <p className="text-[10px] text-slate-400 mt-0.5 font-mono">{loc.battery_level || 100}% batt</p>
                      </div>
                    ) : (
                      <span className="inline-block px-2 py-0.5 rounded-md text-[10px] font-bold bg-amber-50 text-amber-600 dark:bg-amber-950/40 border border-amber-200/50">
                        Awaiting GPS
                      </span>
                    )}
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}
