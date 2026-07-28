import { Check, CheckCheck, FileText, Heart, Activity, Trash2 } from 'lucide-react';

export default function MessageBubble({ msg, isMe, onDelete }) {
  const renderContent = () => {
    switch (msg.message_type) {
      case 'IMAGE':
        return (
          <div className="space-y-2">
            <img 
              src={msg.media_url} 
              alt="Shared media" 
              className="rounded-xl max-w-full h-auto cursor-pointer hover:opacity-90 transition-opacity shadow-sm" 
              onClick={() => window.open(msg.media_url, '_blank')}
            />
            {msg.content && <p className="text-sm px-1">{msg.content}</p>}
          </div>
        );
      
      case 'HEALTH': {
        const data = msg.health_data || {};
        return (
          <div className={`p-4 rounded-2xl border ${isMe ? 'bg-white/10 border-white/20' : 'bg-brand-50 border-brand-100'} space-y-3 min-w-[200px]`}>
            <div className="flex items-center space-x-2">
              <div className={`p-2 rounded-lg ${isMe ? 'bg-white/20' : 'bg-brand-100'}`}>
                <Activity className={`w-4 h-4 ${isMe ? 'text-white' : 'text-brand-600'}`} />
              </div>
              <span className="font-bold text-sm">Health Report</span>
            </div>
            <div className="space-y-1">
              <div className="flex justify-between text-xs">
                <span className="opacity-70">Heart Rate</span>
                <span className="font-bold">{data.heartRate || '72'} bpm</span>
              </div>
              <div className="flex justify-between text-xs">
                <span className="opacity-70">Blood Oxygen</span>
                <span className="font-bold">{data.spO2 || '98'}%</span>
              </div>
            </div>
            <button className={`w-full py-2 rounded-xl text-xs font-bold transition-all ${isMe ? 'bg-white text-brand-600' : 'bg-brand-500 text-white'}`}>
              View Details
            </button>
          </div>
        );
      }

      default:
        return <p className="text-sm leading-relaxed">{msg.content}</p>;
    }
  };

  const renderStatus = () => {
    if (!isMe) return null;
    if (msg.status === 'READ') return <CheckCheck className="w-3.5 h-3.5 text-blue-400" />;
    if (msg.status === 'DELIVERED') return <CheckCheck className="w-3.5 h-3.5 opacity-50" />;
    return <Check className="w-3.5 h-3.5 opacity-50" />;
  };

  return (
    <div className={`flex items-end space-x-2 group relative ${isMe ? 'justify-end' : 'justify-start'}`}>
      {!isMe && (
        <img 
          src={msg.sender_details?.profile_picture || 'https://i.pravatar.cc/150?u=user'} 
          alt="User" 
          className="w-8 h-8 rounded-full mb-1 shadow-sm border border-white" 
        />
      )}
      <div className="flex flex-col space-y-1 max-w-[75%] lg:max-w-[60%] relative">
        <div className={`p-3 rounded-2xl shadow-sm relative ${
          isMe 
            ? 'bg-brand-500 text-white rounded-br-sm' 
            : 'bg-white border border-navy-100 text-navy-900 rounded-bl-sm'
        }`}>
          {renderContent()}
          
          <div className={`flex items-center space-x-1 mt-1 justify-end opacity-70 ${isMe ? 'text-white' : 'text-navy-400'}`}>
            <span className="text-[10px]">
              {new Date(msg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </span>
            {renderStatus()}
          </div>
        </div>
      </div>
      {onDelete && (
        <button
          onClick={() => onDelete(msg.id)}
          className="opacity-0 group-hover:opacity-100 p-1.5 hover:bg-red-50 text-red-500 rounded-lg transition-all"
          title="Delete Message"
        >
          <Trash2 className="w-4 h-4" />
        </button>
      )}
    </div>
  );
}
