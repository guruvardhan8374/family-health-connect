import { useState, useEffect } from 'react';
import { Mic, MicOff, Volume2, Globe, Loader2, Play } from 'lucide-react';

export default function VoiceInterface() {
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [language, setLanguage] = useState('en-US');
  const [aiResponse, setAiResponse] = useState('');

  const languages = [
    { code: 'en-US', name: 'English' },
    { code: 'te-IN', name: 'Telugu' },
    { code: 'hi-IN', name: 'Hindi' },
    { code: 'ta-IN', name: 'Tamil' },
  ];

  const startListening = () => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      alert("Browser doesn't support speech recognition.");
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.lang = language;
    recognition.continuous = false;
    recognition.interimResults = false;

    recognition.onstart = () => setIsListening(true);
    recognition.onend = () => setIsListening(false);
    recognition.onresult = (event) => {
      const text = event.results[0][0].transcript;
      setTranscript(text);
      handleVoiceCommand(text);
    };

    recognition.start();
  };

  const handleVoiceCommand = (text) => {
    // Mocking AI response and TTS
    setAiResponse("Analyzing your request... I've checked your family's health. Everyone is stable.");
    speak("Analyzing your request... I've checked your family's health. Everyone is stable.");
  };

  const speak = (text) => {
    const synth = window.speechSynthesis;
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = language;
    synth.speak(utterance);
  };

  return (
    <div className="bg-white p-8 rounded-[2.5rem] border border-navy-100 shadow-xl space-y-6">
      <div className="flex items-center justify-between">
        <h3 className="text-xl font-bold text-navy-900 flex items-center">
          <Globe className="w-6 h-6 text-brand-500 mr-2" />
          Multilingual Voice AI
        </h3>
        <select 
          value={language} 
          onChange={(e) => setLanguage(e.target.value)}
          className="bg-navy-50 border-none rounded-xl px-4 py-2 text-sm font-bold text-navy-700"
        >
          {languages.map(lang => <option key={lang.code} value={lang.code}>{lang.name}</option>)}
        </select>
      </div>

      <div className="flex flex-col items-center justify-center py-12 space-y-8 bg-navy-50/50 rounded-[2rem] relative overflow-hidden">
        {isListening && (
          <div className="absolute inset-0 bg-brand-500/5 animate-pulse flex items-center justify-center">
            <div className="w-48 h-48 bg-brand-500/10 rounded-full animate-ping"></div>
          </div>
        )}
        
        <button 
          onClick={isListening ? () => {} : startListening}
          className={`w-24 h-24 rounded-full flex items-center justify-center transition-all shadow-2xl relative z-10 ${
            isListening ? 'bg-red-500 text-white animate-bounce' : 'bg-brand-500 text-white hover:scale-110 active:scale-95'
          }`}
        >
          {isListening ? <MicOff className="w-10 h-10" /> : <Mic className="w-10 h-10" />}
        </button>
        
        <div className="text-center space-y-2 relative z-10">
          <p className="text-navy-500 font-bold uppercase tracking-widest text-xs">
            {isListening ? 'Listening...' : 'Tap to speak'}
          </p>
          <p className="text-navy-900 font-medium text-lg min-h-[1.75rem]">
            {transcript || 'Say "Check my heart rate" or "How is Mom?"'}
          </p>
        </div>
      </div>

      {aiResponse && (
        <div className="p-6 bg-brand-50 rounded-2xl border border-brand-100 animate-in fade-in slide-in-from-bottom-4 duration-500">
          <div className="flex items-center text-brand-700 font-bold mb-2">
            <Volume2 className="w-4 h-4 mr-2" />
            <span>AI Assistant</span>
          </div>
          <p className="text-navy-700 leading-relaxed font-medium">{aiResponse}</p>
        </div>
      )}
    </div>
  );
}
