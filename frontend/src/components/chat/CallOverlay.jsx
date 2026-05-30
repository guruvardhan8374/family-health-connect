import { useState, useEffect, useRef } from 'react';
import { Phone, PhoneOff, Mic, MicOff, Video, VideoOff, Maximize, Minimize } from 'lucide-react';

export default function CallOverlay({ 
  localStream, 
  remoteStream, 
  isIncoming, 
  callerName, 
  onAccept, 
  onReject, 
  onEnd,
  callType 
}) {
  const [isMuted, setIsMuted] = useState(false);
  const [isVideoOff, setIsVideoOff] = useState(false);
  const localVideoRef = useRef();
  const remoteVideoRef = useRef();

  useEffect(() => {
    if (localVideoRef.current && localStream) {
      localVideoRef.current.srcObject = localStream;
    }
  }, [localStream]);

  useEffect(() => {
    if (remoteVideoRef.current && remoteStream) {
      remoteVideoRef.current.srcObject = remoteStream;
    }
  }, [remoteStream]);

  const toggleMute = () => {
    localStream.getAudioTracks().forEach(track => track.enabled = isMuted);
    setIsMuted(!isMuted);
  };

  const toggleVideo = () => {
    localStream.getVideoTracks().forEach(track => track.enabled = isVideoOff);
    setIsVideoOff(!isVideoOff);
  };

  return (
    <div className="fixed inset-0 z-[100] bg-navy-900/90 backdrop-blur-2xl flex flex-col animate-in fade-in duration-500">
      {/* Remote Video (Full Screen) */}
      <div className="flex-1 relative overflow-hidden">
        {callType === 'VIDEO' && remoteStream ? (
          <video 
            ref={remoteVideoRef} 
            autoPlay 
            playsInline 
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full flex flex-col items-center justify-center space-y-6">
            <div className="w-40 h-40 bg-brand-500/20 rounded-full flex items-center justify-center animate-pulse">
              <div className="w-32 h-32 bg-brand-500 rounded-full flex items-center justify-center text-4xl font-black text-white">
                {callerName?.charAt(0)}
              </div>
            </div>
            <div className="text-center">
              <h2 className="text-3xl font-black text-white">{callerName}</h2>
              <p className="text-brand-400 font-bold mt-2 uppercase tracking-widest animate-pulse">
                {isIncoming ? 'Incoming Call...' : 'Connecting...'}
              </p>
            </div>
          </div>
        )}

        {/* Local Video (Floating) */}
        {callType === 'VIDEO' && localStream && (
          <div className="absolute top-8 right-8 w-48 h-72 bg-navy-800 rounded-3xl border-2 border-white/20 shadow-2xl overflow-hidden ring-1 ring-black/50">
            <video 
              ref={localVideoRef} 
              autoPlay 
              playsInline 
              muted 
              className="w-full h-full object-cover mirror"
            />
          </div>
        )}
      </div>

      {/* Controls Bar */}
      <div className="h-40 bg-gradient-to-t from-navy-900 to-transparent flex items-center justify-center px-12">
        <div className="bg-white/10 backdrop-blur-xl border border-white/10 p-6 rounded-[3rem] flex items-center space-x-8 shadow-2xl">
          {isIncoming ? (
            <>
              <button 
                onClick={onReject}
                className="bg-red-500 hover:bg-red-600 text-white p-5 rounded-full shadow-lg shadow-red-500/40 transition-all hover:scale-110 active:scale-95"
              >
                <PhoneOff className="w-8 h-8" />
              </button>
              <button 
                onClick={onAccept}
                className="bg-emerald-500 hover:bg-emerald-600 text-white p-5 rounded-full shadow-lg shadow-emerald-500/40 transition-all hover:scale-110 active:scale-95 animate-bounce"
              >
                <Phone className="w-8 h-8" />
              </button>
            </>
          ) : (
            <>
              <button 
                onClick={toggleMute}
                className={`p-4 rounded-2xl transition-all ${isMuted ? 'bg-red-500 text-white' : 'bg-white/10 text-white hover:bg-white/20'}`}
              >
                {isMuted ? <MicOff className="w-6 h-6" /> : <Mic className="w-6 h-6" />}
              </button>
              
              {callType === 'VIDEO' && (
                <button 
                  onClick={toggleVideo}
                  className={`p-4 rounded-2xl transition-all ${isVideoOff ? 'bg-red-500 text-white' : 'bg-white/10 text-white hover:bg-white/20'}`}
                >
                  {isVideoOff ? <VideoOff className="w-6 h-6" /> : <Video className="w-6 h-6" />}
                </button>
              )}

              <button 
                onClick={onEnd}
                className="bg-red-500 hover:bg-red-600 text-white p-6 rounded-[2rem] shadow-lg shadow-red-500/40 transition-all hover:scale-110 active:scale-95"
              >
                <PhoneOff className="w-8 h-8" />
              </button>

              <button className="p-4 bg-white/10 text-white rounded-2xl hover:bg-white/20 transition-all">
                <Maximize className="w-6 h-6" />
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
