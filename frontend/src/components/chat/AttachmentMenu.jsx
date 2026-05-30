import { Image, FileText, Camera, Activity, X } from 'lucide-react';

export default function AttachmentMenu({ onSelect, onClose }) {
  const options = [
    { id: 'IMAGE', icon: Image, label: 'Photos & Videos', color: 'bg-purple-500' },
    { id: 'CAMERA', icon: Camera, label: 'Camera', color: 'bg-red-500' },
    { id: 'DOCUMENT', icon: FileText, label: 'Document', color: 'bg-blue-500' },
    { id: 'HEALTH', icon: Activity, label: 'Health Report', color: 'bg-brand-500' },
  ];

  return (
    <div className="absolute bottom-20 left-4 bg-white/90 backdrop-blur-xl border border-white/20 p-4 rounded-[2.5rem] shadow-2xl z-50 animate-in fade-in slide-in-from-bottom-4 duration-300">
      <div className="flex flex-col space-y-4">
        {options.map((opt) => (
          <button
            key={opt.id}
            onClick={() => onSelect(opt.id)}
            className="flex items-center space-x-4 p-2 hover:bg-navy-50 rounded-2xl transition-colors group"
          >
            <div className={`${opt.color} p-3 rounded-full text-white shadow-lg group-hover:scale-110 transition-transform`}>
              <opt.icon className="w-5 h-5" />
            </div>
            <span className="text-sm font-bold text-navy-900 pr-4">{opt.label}</span>
          </button>
        ))}
      </div>
      <button 
        onClick={onClose}
        className="absolute -top-2 -right-2 bg-navy-900 text-white p-1 rounded-full shadow-lg"
      >
        <X className="w-4 h-4" />
      </button>
    </div>
  );
}
