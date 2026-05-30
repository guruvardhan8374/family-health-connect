import { useState } from 'react';
import { Bot, X, Send, Sparkles } from 'lucide-react';
import { cn } from '../utils/cn';
import api from '../utils/api';

export default function AIChatbot() {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState([
    { role: 'ai', content: 'Hi! I am your Family Health AI. How can I help you today?' }
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [suggestions, setSuggestions] = useState(['How to sleep better?', 'Health recommendations?', 'Stress management']);

  const handleSend = async (msgContent) => {
    const text = msgContent || input;
    if (!text.trim()) return;
    
    setMessages(prev => [...prev, { role: 'user', content: text }]);
    setInput('');
    setLoading(true);

    try {
      const response = await api.post('/chat/ai-assistant/', {
        prompt: text,
        context_type: 'HEALTH'
      });
      
      setMessages(prev => [...prev, { role: 'ai', content: response.data.analysis }]);
      setSuggestions([
        "How to improve sleep?",
        "Check my activity logs",
        "Explain normal heart rate ranges"
      ]);
    } catch (err) {
      console.error("AI Assistant chat failed:", err);
      setMessages(prev => [...prev, { role: 'ai', content: "I'm having trouble connecting to my AI module right now. Please verify your internet connection and try again." }]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      {/* Floating Button */}
      <button 
        onClick={() => setIsOpen(true)}
        className={cn(
          "fixed bottom-6 right-6 p-4 rounded-full bg-brand-500 text-white shadow-lg shadow-brand-500/30 hover:scale-105 transition-all z-50 flex items-center space-x-2 group",
          isOpen && "scale-0 opacity-0"
        )}
      >
        <Bot className="w-6 h-6" />
        <span className="font-medium max-w-0 overflow-hidden group-hover:max-w-xs transition-all duration-300 ease-in-out whitespace-nowrap">
          Ask Family AI
        </span>
      </button>

      {/* Chat Window */}
      <div 
        className={cn(
          "fixed bottom-6 right-6 w-80 sm:w-96 h-[500px] bg-white/90 backdrop-blur-xl border border-white rounded-3xl shadow-2xl flex flex-col z-50 transition-all duration-300 origin-bottom-right overflow-hidden",
          isOpen ? "scale-100 opacity-100" : "scale-0 opacity-0 pointer-events-none"
        )}
      >
        {/* Header */}
        <div className="p-4 bg-gradient-to-r from-brand-500 to-brand-600 flex justify-between items-center text-white shrink-0">
          <div className="flex items-center space-x-2">
            <div className="bg-white/20 p-1.5 rounded-xl">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold leading-tight">Health AI</h3>
              <p className="text-xs text-brand-100">Powered by TensorFlow</p>
            </div>
          </div>
          <button onClick={() => setIsOpen(false)} className="p-1 hover:bg-white/20 rounded-full transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.map((msg, i) => (
            <div key={i} className={cn("flex", msg.role === 'user' ? "justify-end" : "justify-start")}>
              <div className={cn(
                "max-w-[80%] p-3 text-sm rounded-2xl shadow-sm",
                msg.role === 'user' 
                  ? "bg-navy-900 text-white rounded-br-sm" 
                  : "bg-brand-50 border border-brand-100 text-navy-900 rounded-bl-sm"
              )}>
                {msg.content}
              </div>
            </div>
          ))}
          {loading && (
            <div className="flex justify-start">
              <div className="bg-brand-50 border border-brand-100 p-3 rounded-2xl rounded-bl-sm flex space-x-1">
                <div className="w-1.5 h-1.5 bg-brand-400 rounded-full animate-bounce"></div>
                <div className="w-1.5 h-1.5 bg-brand-400 rounded-full animate-bounce" style={{ animationDelay: '0.2s' }}></div>
                <div className="w-1.5 h-1.5 bg-brand-400 rounded-full animate-bounce" style={{ animationDelay: '0.4s' }}></div>
              </div>
            </div>
          )}
          
          {!loading && suggestions.length > 0 && (
            <div className="flex flex-wrap gap-2 mt-4">
              {suggestions.map((s, i) => (
                <button
                  key={i}
                  onClick={() => handleSend(s)}
                  className="text-xs bg-white border border-navy-100 text-navy-600 px-3 py-1.5 rounded-full hover:border-brand-300 hover:text-brand-600 transition-all"
                >
                  {s}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Input */}
        <div className="p-3 border-t border-navy-100 bg-white shrink-0">
          <div className="flex items-center bg-navy-50 rounded-full p-1 pr-1.5 border border-navy-100 focus-within:border-brand-300 focus-within:bg-white transition-colors">
            <input 
              type="text" 
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleSend()}
              placeholder="Ask about family health..." 
              className="flex-1 bg-transparent border-none focus:ring-0 text-sm text-navy-900 px-4 py-2 outline-none"
            />
            <button 
              onClick={handleSend}
              className="bg-brand-500 text-white p-2 rounded-full hover:bg-brand-600 transition-colors shadow-sm"
            >
              <Send className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </>
  );
}
