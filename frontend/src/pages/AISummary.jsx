import { useState, useEffect, useRef } from 'react';
import {
  Brain, Send, Loader2, Bot, User, Sparkles,
  HeartPulse, Activity, Droplets, Moon, RefreshCw, AlertCircle
} from 'lucide-react';
import api from '../utils/api';

const QUICK_PROMPTS = [
  { label: 'Heart Rate', icon: HeartPulse, prompt: 'What is a healthy heart rate range for adults?' },
  { label: 'Sleep Tips', icon: Moon,       prompt: 'How many hours of sleep does my family need?' },
  { label: 'Hydration',  icon: Droplets,   prompt: 'How much water should we drink daily?' },
  { label: 'Exercise',   icon: Activity,   prompt: 'What exercise is best for family health?' },
];

export default function AISummary() {
  const [messages, setMessages]   = useState([
    {
      id: 1,
      role: 'assistant',
      text: "Hi! I'm your Family Health AI Assistant 🩺\n\nI can answer health questions, analyze your family's wellness, and give personalised tips. What would you like to know?",
      ts: new Date().toISOString(),
    }
  ]);
  const [input, setInput]         = useState('');
  const [loading, setLoading]     = useState(false);
  const [contextType, setContextType] = useState('HEALTH');
  const [fallbackNote, setFallbackNote] = useState('');

  const bottomRef = useRef(null);
  const inputRef  = useRef(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const sendMessage = async (promptText) => {
    const text = (promptText || input).trim();
    if (!text || loading) return;

    setInput('');
    setFallbackNote('');

    // Add user message immediately
    const userMsg = { id: Date.now(), role: 'user', text, ts: new Date().toISOString() };
    setMessages(prev => [...prev, userMsg]);
    setLoading(true);

    try {
      const res = await api.post('/chat/ai-assistant/', {
        prompt: text,
        context_type: contextType,
      });

      const data = res.data;
      const aiMsg = {
        id: Date.now() + 1,
        role: 'assistant',
        text: data.analysis || 'I could not generate a response. Please try again.',
        ts: new Date().toISOString(),
        fallback: data.fallback,
      };
      setMessages(prev => [...prev, aiMsg]);

      if (data.fallback && data.api_error) {
        setFallbackNote('AI is running in offline mode — Gemini API key may not be configured on the server.');
      }
    } catch (err) {
      const isAuth = err.response?.status === 401;
      setMessages(prev => [...prev, {
        id: Date.now() + 1,
        role: 'error',
        text: isAuth
          ? 'Your session expired. Please log in again.'
          : 'Failed to reach the AI service. Please check your connection and try again.',
        ts: new Date().toISOString(),
      }]);
    } finally {
      setLoading(false);
      inputRef.current?.focus();
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    sendMessage();
  };

  const clearChat = () => {
    setMessages([{
      id: Date.now(),
      role: 'assistant',
      text: "Chat cleared! How can I help your family today?",
      ts: new Date().toISOString(),
    }]);
    setFallbackNote('');
  };

  return (
    <div className="max-w-3xl mx-auto flex flex-col h-[calc(100vh-120px)] pb-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 bg-brand-500 rounded-2xl flex items-center justify-center shadow-lg shadow-brand-500/30">
            <Brain className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-xl font-extrabold text-navy-900">Family Health AI</h1>
            <p className="text-xs text-navy-400 font-medium">Powered by Gemini · Always available</p>
          </div>
        </div>
        <div className="flex items-center space-x-2">
          {/* Context type toggle */}
          <div className="flex items-center bg-navy-50 rounded-2xl p-1 border border-navy-100">
            {['HEALTH', 'CHAT'].map(t => (
              <button
                key={t}
                onClick={() => setContextType(t)}
                className={`px-4 py-1.5 rounded-xl text-xs font-black transition-all ${
                  contextType === t
                    ? 'bg-brand-500 text-white shadow-sm'
                    : 'text-navy-400 hover:text-navy-700'
                }`}
              >
                {t === 'HEALTH' ? '🩺 Health' : '💬 General'}
              </button>
            ))}
          </div>
          <button
            onClick={clearChat}
            className="p-2 text-navy-400 hover:text-navy-700 hover:bg-navy-50 rounded-xl transition-all"
            title="Clear chat"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Offline warning */}
      {fallbackNote && (
        <div className="mb-3 px-4 py-3 bg-amber-50 border border-amber-200 rounded-2xl flex items-center space-x-2 text-amber-700 text-xs font-semibold">
          <AlertCircle className="w-4 h-4 shrink-0" />
          <span>{fallbackNote}</span>
        </div>
      )}

      {/* Messages */}
      <div className="flex-1 overflow-y-auto space-y-4 pr-1">
        {messages.map(msg => (
          <div
            key={msg.id}
            className={`flex items-end gap-3 ${msg.role === 'user' ? 'flex-row-reverse' : 'flex-row'}`}
          >
            {/* Avatar */}
            <div className={`w-8 h-8 rounded-2xl flex items-center justify-center shrink-0 ${
              msg.role === 'user'    ? 'bg-brand-500 text-white' :
              msg.role === 'error'  ? 'bg-red-100 text-red-500' :
              'bg-emerald-50 border border-emerald-200 text-emerald-600'
            }`}>
              {msg.role === 'user'   ? <User className="w-4 h-4" />   :
               msg.role === 'error'  ? <AlertCircle className="w-4 h-4" /> :
               <Bot className="w-4 h-4" />}
            </div>

            {/* Bubble */}
            <div className={`max-w-[80%] px-5 py-3 rounded-[1.5rem] text-sm leading-relaxed whitespace-pre-wrap ${
              msg.role === 'user'   ? 'bg-brand-500 text-white rounded-br-md' :
              msg.role === 'error'  ? 'bg-red-50 border border-red-200 text-red-700 rounded-bl-md' :
              'bg-white border border-navy-100 text-navy-800 rounded-bl-md shadow-sm'
            }`}>
              {msg.text}
              {msg.fallback && (
                <span className="block mt-1 text-[10px] text-navy-400 font-semibold">
                  ⚡ Offline mode — configure GEMINI_API_KEY for live AI
                </span>
              )}
            </div>
          </div>
        ))}

        {/* Typing indicator */}
        {loading && (
          <div className="flex items-end gap-3">
            <div className="w-8 h-8 rounded-2xl bg-emerald-50 border border-emerald-200 flex items-center justify-center">
              <Bot className="w-4 h-4 text-emerald-600" />
            </div>
            <div className="bg-white border border-navy-100 rounded-[1.5rem] rounded-bl-md px-5 py-4 shadow-sm">
              <div className="flex space-x-1.5">
                {[0,1,2].map(i => (
                  <div
                    key={i}
                    className="w-2 h-2 bg-brand-400 rounded-full animate-bounce"
                    style={{ animationDelay: `${i * 0.15}s` }}
                  />
                ))}
              </div>
            </div>
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      {/* Quick prompt chips */}
      {messages.length <= 2 && !loading && (
        <div className="mt-3 mb-2 flex flex-wrap gap-2">
          {QUICK_PROMPTS.map(({ label, icon: Icon, prompt }) => (
            <button
              key={label}
              onClick={() => sendMessage(prompt)}
              className="flex items-center space-x-1.5 px-4 py-2 bg-white border border-navy-100 rounded-2xl text-xs font-bold text-navy-700 hover:border-brand-500 hover:text-brand-600 hover:bg-brand-50 transition-all shadow-sm"
            >
              <Icon className="w-3.5 h-3.5" />
              <span>{label}</span>
            </button>
          ))}
        </div>
      )}

      {/* Input */}
      <form onSubmit={handleSubmit} className="mt-3 flex items-center gap-3">
        <div className="flex-1 flex items-center bg-white border border-navy-100 rounded-[1.5rem] px-5 py-3 shadow-sm focus-within:border-brand-500 transition-colors">
          <Sparkles className="w-4 h-4 text-brand-400 mr-3 shrink-0" />
          <input
            ref={inputRef}
            type="text"
            value={input}
            onChange={e => setInput(e.target.value)}
            placeholder="Ask about sleep, heart rate, diet…"
            className="flex-1 bg-transparent outline-none text-sm text-navy-900 placeholder-navy-400 font-medium"
            disabled={loading}
          />
        </div>
        <button
          type="submit"
          disabled={!input.trim() || loading}
          className="w-12 h-12 bg-brand-500 hover:bg-brand-600 disabled:opacity-40 disabled:cursor-not-allowed text-white rounded-[1.2rem] flex items-center justify-center shadow-lg shadow-brand-500/30 transition-all"
        >
          {loading ? <Loader2 className="w-5 h-5 animate-spin" /> : <Send className="w-5 h-5" />}
        </button>
      </form>
    </div>
  );
}
