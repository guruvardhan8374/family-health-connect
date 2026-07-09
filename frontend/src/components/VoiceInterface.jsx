import { useState } from 'react';
import { Mic, MicOff, Volume2, Globe, Loader2 } from 'lucide-react';
import api from '../utils/api';

const LANGUAGES = [
  { code: 'en-US', name: 'English' },
  { code: 'te-IN', name: 'Telugu' },
  { code: 'hi-IN', name: 'Hindi' },
  { code: 'ta-IN', name: 'Tamil' },
];

export default function VoiceInterface() {
  const [isListening, setIsListening]   = useState(false);
  const [transcript, setTranscript]     = useState('');
  const [language, setLanguage]         = useState('en-US');
  const [aiResponse, setAiResponse]     = useState('');
  const [loading, setLoading]           = useState(false);
  const [error, setError]               = useState('');

  // ── Text-to-Speech helper ──────────────────────────────────────────────
  const speak = (text) => {
    if (!window.speechSynthesis) return;
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = language;
    utterance.rate = 0.95;
    window.speechSynthesis.speak(utterance);
  };

  // ── Send transcript to backend AI ─────────────────────────────────────
  const handleVoiceCommand = async (text) => {
    if (!text.trim()) return;
    setLoading(true);
    setError('');
    setAiResponse('');
    try {
      const res = await api.post('/chat/ai-assistant/', {
        prompt: text,
        context_type: 'HEALTH',
      });
      const reply = res.data?.analysis || 'Sorry, I could not generate a response.';
      setAiResponse(reply);
      speak(reply);
    } catch (err) {
      const msg = err.response?.status === 401
        ? 'Session expired. Please log in again.'
        : 'Could not reach the AI service. Please try again.';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  // ── Start speech recognition ───────────────────────────────────────────
  const startListening = () => {
    const SpeechRecognition =
      window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      setError("Your browser doesn't support speech recognition. Try Chrome.");
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.lang           = language;
    recognition.continuous     = false;
    recognition.interimResults = false;

    recognition.onstart  = () => { setIsListening(true); setError(''); };
    recognition.onend    = () => setIsListening(false);
    recognition.onerror  = (e) => {
      setIsListening(false);
      if (e.error !== 'no-speech') setError(`Microphone error: ${e.error}`);
    };
    recognition.onresult = (event) => {
      const text = event.results[0][0].transcript;
      setTranscript(text);
      handleVoiceCommand(text);
    };

    recognition.start();
  };

  return (
    <div className="bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-xl space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h3 className="text-xl font-bold text-navy-900 flex items-center">
          <Globe className="w-6 h-6 text-brand-500 mr-2" />
          Multilingual Voice AI
        </h3>
        <select
          value={language}
          onChange={(e) => setLanguage(e.target.value)}
          className="bg-navy-50 border-none rounded-xl px-4 py-2 text-sm font-bold text-navy-700 focus:outline-none"
        >
          {LANGUAGES.map(l => (
            <option key={l.code} value={l.code}>{l.name}</option>
          ))}
        </select>
      </div>

      {/* Mic area */}
      <div className="flex flex-col items-center justify-center py-10 space-y-6 bg-navy-50/50 rounded-[2rem] relative overflow-hidden">
        {isListening && (
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            <div className="w-40 h-40 bg-brand-500/10 rounded-full animate-ping" />
          </div>
        )}

        <button
          onClick={isListening ? () => {} : startListening}
          disabled={loading}
          className={`w-24 h-24 rounded-full flex items-center justify-center transition-all shadow-2xl relative z-10 disabled:opacity-50 ${
            isListening
              ? 'bg-red-500 text-white animate-pulse'
              : 'bg-brand-500 text-white hover:scale-110 active:scale-95'
          }`}
          title={isListening ? 'Listening…' : 'Tap to speak'}
        >
          {loading
            ? <Loader2 className="w-10 h-10 animate-spin" />
            : isListening
            ? <MicOff className="w-10 h-10" />
            : <Mic className="w-10 h-10" />
          }
        </button>

        <div className="text-center space-y-1 relative z-10 px-4">
          <p className="text-navy-500 font-bold uppercase tracking-widest text-xs">
            {loading ? 'Thinking…' : isListening ? 'Listening…' : 'Tap to speak'}
          </p>
          <p className="text-navy-900 font-medium text-base min-h-[1.5rem]">
            {transcript || 'Say "Check my heart rate" or "How is my sleep?"'}
          </p>
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="px-4 py-3 bg-red-50 border border-red-200 rounded-2xl text-red-600 text-sm font-semibold">
          {error}
        </div>
      )}

      {/* AI Response */}
      {aiResponse && (
        <div className="p-6 bg-brand-50 rounded-2xl border border-brand-100 animate-in fade-in slide-in-from-bottom-4 duration-500">
          <div className="flex items-center justify-between text-brand-700 font-bold mb-2">
            <div className="flex items-center space-x-2">
              <Volume2 className="w-4 h-4" />
              <span>AI Response</span>
            </div>
            <button
              onClick={() => speak(aiResponse)}
              className="text-xs text-brand-500 hover:text-brand-700 font-semibold underline transition-colors"
            >
              Replay
            </button>
          </div>
          <p className="text-navy-700 leading-relaxed font-medium text-sm">{aiResponse}</p>
        </div>
      )}
    </div>
  );
}
