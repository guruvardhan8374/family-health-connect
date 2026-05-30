import { useEffect, useState, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import { io } from 'socket.io-client';

// Custom Marker Creator
const createCustomIcon = (url) => {
  return new L.DivIcon({
    html: `<div class="relative w-12 h-12">
            <img src="${url}" class="w-12 h-12 rounded-full border-4 border-white shadow-lg object-cover" />
            <div class="absolute -bottom-1 -right-1 w-4 h-4 bg-emerald-500 border-2 border-white rounded-full"></div>
           </div>`,
    className: 'custom-marker-icon',
    iconSize: [48, 48],
    iconAnchor: [24, 48],
  });
};

function MapController({ center }) {
  const map = useMap();
  useEffect(() => {
    if (center) {
      map.setView(center, map.getZoom());
    }
  }, [center, map]);
  return null;
}

const defaultCenter = [40.7128, -74.0060];

export default function FamilyMap() {
  const [locations, setLocations] = useState({
    'Mom': { lat: 40.7138, lng: -74.0070, avatar: 'https://i.pravatar.cc/150?u=mom' },
    'Dad': { lat: 40.7118, lng: -74.0050, avatar: 'https://i.pravatar.cc/150?u=dad' },
  });
  const [myLocation, setMyLocation] = useState(null);
  const socketRef = useRef(null);

  useEffect(() => {
    // Connect to FastAPI Socket.IO server
    socketRef.current = io('http://localhost:8001');

    socketRef.current.on('family_location', (data) => {
      if (data.user && data.lat && data.lng) {
        setLocations(prev => ({
          ...prev,
          [data.user]: { lat: data.lat, lng: data.lng, avatar: data.avatar }
        }));
      }
    });

    // Start watching position
    const watchId = navigator.geolocation.watchPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        const newLoc = { lat: latitude, lng: longitude };
        setMyLocation(newLoc);
        
        // Emit to server
        socketRef.current.emit('location_update', {
          user: 'Pravi', // Should be dynamic from auth context
          avatar: 'https://i.pravatar.cc/150?u=pravi',
          lat: latitude,
          lng: longitude
        });
      },
      (error) => console.error('Error watching position:', error),
      { enableHighAccuracy: true, maximumAge: 10000, timeout: 5000 }
    );

    return () => {
      socketRef.current.disconnect();
      navigator.geolocation.clearWatch(watchId);
    };
  }, []);

  return (
    <div className="h-[400px] w-full rounded-[2.5rem] overflow-hidden border border-navy-100 shadow-xl relative z-0">
      <MapContainer center={myLocation ? [myLocation.lat, myLocation.lng] : defaultCenter} zoom={15} style={{ height: '100%', width: '100%' }}>
        <TileLayer
          url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        />
        <MapController center={myLocation ? [myLocation.lat, myLocation.lng] : null} />
        
        {myLocation && (
          <Marker position={[myLocation.lat, myLocation.lng]} icon={createCustomIcon('https://i.pravatar.cc/150?u=pravi')}>
            <Popup className="custom-popup">
              <div className="p-1 font-bold text-navy-900">You are here</div>
            </Popup>
          </Marker>
        )}

        {Object.entries(locations).map(([user, data]) => (
          <Marker key={user} position={[data.lat, data.lng]} icon={createCustomIcon(data.avatar)}>
            <Popup>
              <div className="p-1">
                <p className="font-bold text-navy-900">{user}</p>
                <p className="text-xs text-emerald-500 font-medium">Live now</p>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}
