import { Plus, HeartPulse } from 'lucide-react';

export default function StoryBar({ stories, onAddStory, onViewStory }) {
  const currentUser = { id: 1, name: 'Pravi' }; // Mock

  return (
    <div className="flex items-center space-x-4 p-6 overflow-x-auto scrollbar-hide bg-white/40 backdrop-blur-md border-b border-navy-100/30">
      {/* Add Story Button */}
      <div className="flex flex-col items-center space-y-2 flex-shrink-0 cursor-pointer group" onClick={onAddStory}>
        <div className="relative">
          <div className="w-16 h-16 bg-brand-500/10 rounded-[1.5rem] border-2 border-dashed border-brand-500/30 flex items-center justify-center group-hover:border-brand-500 transition-all duration-300">
            <Plus className="w-6 h-6 text-brand-500 group-hover:scale-125 transition-transform" />
          </div>
          <div className="absolute -bottom-1 -right-1 w-6 h-6 bg-brand-500 border-4 border-white rounded-full flex items-center justify-center">
            <Plus className="w-3 h-3 text-white" />
          </div>
        </div>
        <span className="text-[10px] font-black text-navy-900 uppercase tracking-widest">My Story</span>
      </div>

      {/* Stories List */}
      {stories.map((story) => (
        <div 
          key={story.id} 
          className="flex flex-col items-center space-y-2 flex-shrink-0 cursor-pointer"
          onClick={() => onViewStory(story)}
        >
          <div className="relative p-[3px] rounded-[1.6rem] bg-gradient-to-tr from-brand-400 via-blue-500 to-emerald-400 animate-gradient-xy">
            <div className="bg-white p-[2px] rounded-[1.5rem]">
              <div className="relative w-14 h-14 rounded-[1.3rem] overflow-hidden">
                {story.story_type === 'HEALTH' ? (
                  <div className="w-full h-full bg-navy-900 flex items-center justify-center">
                    <HeartPulse className="w-6 h-6 text-brand-400 animate-pulse" />
                  </div>
                ) : (
                  <img 
                    src={story.media_url || 'https://i.pravatar.cc/150'} 
                    alt={story.username} 
                    className="w-full h-full object-cover"
                  />
                )}
              </div>
            </div>
          </div>
          <span className="text-[10px] font-bold text-navy-500 truncate w-16 text-center">
            {story.username}
          </span>
        </div>
      ))}
    </div>
  );
}
