import { useState, useEffect, useRef, useCallback } from 'react';
import { 
  Send, Loader2, MoreVertical, Paperclip, 
  Search, Smile, Mic, Pin, Archive, Trash2,
  Check, CheckCheck, X, Plus, Users, User
} from 'lucide-react';
import api from '../utils/api';
import MessageBubble from '../components/chat/MessageBubble';
import AttachmentMenu from '../components/chat/AttachmentMenu';
import { useAuth } from '../contexts/AuthContext';

export default function Chat() {
  const { user: authUser } = useAuth();
  const currentUser = {
    id: authUser?.id || parseInt(localStorage.getItem('user_id')) || 0,
    name: authUser?.username || localStorage.getItem('username') || 'Me'
  };

  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [conversations, setConversations] = useState([]);
  const [activeConv, setActiveConv] = useState(null);
  const [loading, setLoading] = useState(false);
  const [showAttachments, setShowAttachments] = useState(false);
  const [typingUsers, setTypingUsers] = useState({});
  const [onlineStatus, setOnlineStatus] = useState({});
  const [searchQuery, setSearchQuery] = useState('');
  const [checkingFamily, setCheckingFamily] = useState(true);
  const [hasFamily, setHasFamily] = useState(false);

  // New Chat States
  const [showNewChatModal, setShowNewChatModal] = useState(false);
  const [familyMembers, setFamilyMembers] = useState([]);
  const [familyGroups, setFamilyGroups] = useState([]);

  const socketRef = useRef(null);
  const scrollRef = useRef(null);

  const fetchConvs = useCallback(async () => {
    try {
      const res = await api.get('/chat/conversations/');
      const convList = res.data.results || res.data || [];
      setConversations(convList);

      const params = new URLSearchParams(window.location.search);
      const paramFamilyId = params.get('family_group_id') || params.get('group_id') || localStorage.getItem('active_family_group_id');
      const paramUserId = params.get('user_id');

      if (paramUserId) {
        try {
          const privRes = await api.post('/chat/conversations/private/', { recipient_id: parseInt(paramUserId) });
          if (privRes.data) {
            setActiveConv(privRes.data);
            return;
          }
        } catch (e) {
          console.error('Failed to get/create private conv:', e);
        }
      }

      if (paramFamilyId) {
        const matchingGroupConv = convList.find(c => c.family_group === parseInt(paramFamilyId) || c.family_group?.id === parseInt(paramFamilyId));
        if (matchingGroupConv) {
          setActiveConv(matchingGroupConv);
          return;
        } else {
          try {
            const groupConvRes = await api.get(`/chat/conversations/by-family/?family_group_id=${paramFamilyId}`);
            if (groupConvRes.data) {
              setActiveConv(groupConvRes.data);
              setConversations(prev => [groupConvRes.data, ...prev.filter(c => c.id !== groupConvRes.data.id)]);
              return;
            }
          } catch (e) {
            console.error('Failed to get/create family group conv:', e);
          }
        }
      }

      setActiveConv(prev => prev || (convList.length > 0 ? convList[0] : null));
    } catch (err) { console.error(err); }
  }, []);

  const updateConvList = useCallback((msg) => {
    setConversations(prev => prev.map(c => c.id === msg.conversation ? { ...c, latest_message: msg } : c));
  }, []);

  const fetchMessages = useCallback(async (convId, silent = false) => {
    if (!convId) return;
    if (!silent) setLoading(true);
    try {
      const res = await api.get(`/chat/messages/?conversation=${convId}`);
      const msgs = res.data.results || res.data || [];
      const reversed = msgs.slice().reverse();
      
      setMessages(prev => {
        if (prev.length === reversed.length && prev.every((m, idx) => m.id === reversed[idx]?.id)) {
          return prev;
        }
        return reversed;
      });
      
      api.post('/chat/messages/mark-read/', { conversation: convId }).catch(err => console.error(err));
    } catch (err) { 
      console.error(err); 
    } finally { 
      if (!silent) setLoading(false); 
    }
  }, []);

  // Verify family membership first on mount, and then fetch details
  useEffect(() => {
    const checkFamilyAndInit = async () => {
      try {
        const groupsRes = await api.get('/family/groups/');
        const groups = groupsRes.data.results || groupsRes.data || [];
        if (groups.length === 0) {
          setHasFamily(false);
        } else {
          setHasFamily(true);
          await fetchConvs();
        }
      } catch (err) {
        console.error("Failed to verify family circle status:", err);
        if (err.response?.status !== 401) {
          setHasFamily(false);
        }
      } finally {
        setCheckingFamily(false);
      }
    };
    checkFamilyAndInit();
  }, []);

  // Fetch messages when activeConv changes
  useEffect(() => {
    if (activeConv?.id) {
      fetchMessages(activeConv.id);
    }
  }, [activeConv?.id, fetchMessages]);

  // Establish real-time WebSocket connection to Django Channels ASGI on activeConv change
  useEffect(() => {
    if (!activeConv || !hasFamily) return;

    const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
    const wsBaseUrl = apiBaseUrl.replace(/^http/, 'ws');
    const token = localStorage.getItem('access_token');
    const wsUrl = `${wsBaseUrl}/ws/chat/${activeConv.id}/?token=${token}`;

    console.log("[WebSocket] Connecting to:", wsUrl);
    const ws = new WebSocket(wsUrl);
    socketRef.current = ws;

    ws.onopen = () => {
      console.log("[WebSocket] Connected successfully!");
      setOnlineStatus(prev => ({ ...prev, [currentUser.id]: 'online' }));
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        console.log("[WebSocket] Received broadcast payload:", data);
        
        if (data.type === 'chat_message') {
          const formattedMsg = {
            id: data.id,
            conversation: activeConv.id,
            content: data.content,
            sender: data.sender_id,
            sender_details: {
              id: data.sender_id,
              username: data.sender_username,
              profile_picture: `https://i.pravatar.cc/150?u=${data.sender_id}`
            },
            message_type: data.message_type,
            media_url: data.media_url,
            health_data: data.health_data,
            timestamp: data.timestamp
          };

          setMessages(prev => {
            if (prev.some(m => m.id === formattedMsg.id)) return prev;
            return [...prev, formattedMsg];
          });

          api.post('/chat/messages/mark-read/', { conversation: activeConv.id }).catch(err => console.error(err));
          updateConvList(formattedMsg);
        }
      } catch (err) {
        console.error("[WebSocket] Failed to parse message:", err);
      }
    };

    ws.onerror = (err) => {
      console.error("[WebSocket] Socket encountered error:", err);
    };

    ws.onclose = (event) => {
      console.log(`[WebSocket] Closed connection code: ${event.code}. Reason: ${event.reason}`);
    };

    return () => {
      console.log("[WebSocket] Cleaning up connection...");
      ws.close();
    };
  }, [activeConv, hasFamily, updateConvList, currentUser.id]);



  const handleAddStory = async () => {
    const media_url = prompt("Enter an image URL for your story:");
    if (!media_url) return;
    try {
      const res = await api.post('/chat/stories/', { media_url, story_type: 'IMAGE' });
      setStories(prev => [res.data, ...prev]);
    } catch (err) { console.error(err); }
  };

  const handleOpenNewChat = async () => {
    try {
      const membersRes = await api.get('/family/members/');
      const list = membersRes.data.results || membersRes.data || [];
      const uniqueMembers = [];
      const seen = new Set();
      list.forEach(m => {
        if (m.is_approved && m.user !== currentUser.id && m.user_details) {
          if (!seen.has(m.user)) {
            seen.add(m.user);
            uniqueMembers.push(m);
          }
        }
      });
      setFamilyMembers(uniqueMembers);

      const groupsRes = await api.get('/family/groups/');
      setFamilyGroups(groupsRes.data.results || groupsRes.data || []);

      setShowNewChatModal(true);
    } catch (err) {
      console.error("Failed to load family circle members/groups:", err);
      alert("Failed to load family members. Ensure you have created or joined a Family Circle first!");
    }
  };

  const handleStartPrivateChat = async (recipientId) => {
    try {
      const res = await api.post('/chat/conversations/private/', { recipient_id: recipientId });
      const newConv = res.data;
      setConversations(prev => {
        if (prev.some(c => c.id === newConv.id)) return prev;
        return [newConv, ...prev];
      });
      setActiveConv(newConv);
      setShowNewChatModal(false);
    } catch (err) {
      console.error("Failed to start private chat:", err);
      alert("Failed to start chat session.");
    }
  };

  const handleStartGroupChat = async (groupId, groupName) => {
    try {
      const res = await api.post('/chat/conversations/group/', { 
        family_group_id: groupId,
        name: groupName 
      });
      const newConv = res.data;
      setConversations(prev => {
        if (prev.some(c => c.id === newConv.id)) return prev;
        return [newConv, ...prev];
      });
      setActiveConv(newConv);
      setShowNewChatModal(false);
    } catch (err) {
      console.error("Failed to start group chat:", err);
      alert("Failed to start group chat session.");
    }
  };

  // Safe wrapper for call signaling (stub WebRTC because ASGI Django Channels only supports chat messages)
  const initWebRTC = async (stream) => {
    const pc = new RTCPeerConnection({
      iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
    });
    stream.getTracks().forEach(track => pc.addTrack(track, stream));
    pc.ontrack = (event) => setRemoteStream(event.streams[0]);
    pc.onicecandidate = (event) => {
      if (event.candidate && remoteSid && socketRef.current?.emit) {
        socketRef.current.emit('webrtc-signal', { to_sid: remoteSid, signal: { candidate: event.candidate } });
      }
    };
    pcRef.current = pc;
    return pc;
  };

  const initiateCall = async (type) => {
    if (!activeConv) return;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: type === 'VIDEO', audio: true });
      setLocalStream(stream);
      setCallActive(true);
      setCallType(type);
      setIsIncoming(false);
      setCallerName(activeConv.is_group ? activeConv.name : activeConv.participants_details[0]?.username);

      const pc = await initWebRTC(stream);
      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      const to_user_id = activeConv.is_group ? null : activeConv.participants[0];
      if (socketRef.current?.emit) {
        socketRef.current.emit('call-user', {
          to_user_id,
          from_user_name: currentUser.name,
          call_type: type,
          offer,
          conversation_id: activeConv.id
        });
      } else {
        console.log("Call feature requires Socket.io server connection. WebRTC call initiated locally.");
      }
    } catch (err) {
      console.error("Camera/Mic access denied or RTC failed:", err);
      alert("Please allow Camera and Microphone permissions to make calls!");
    }
  };

  const acceptCall = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: callType === 'VIDEO', audio: true });
      setLocalStream(stream);
      setIsIncoming(false);
      const pc = await initWebRTC(stream);
      await pc.setRemoteDescription(new RTCSessionDescription(pendingOffer));
      const answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      if (socketRef.current?.emit) {
        socketRef.current.emit('answer-call', { to_sid: remoteSid, answer });
      }
    } catch (err) {
      console.error(err);
    }
  };

  const endCall = () => {
    if (localStream) localStream.getTracks().forEach(track => track.stop());
    if (pcRef.current) pcRef.current.close();
    setCallActive(false);
    setLocalStream(null);
    setRemoteStream(null);
    pcRef.current = null;
    if (socketRef.current?.emit) {
      socketRef.current.emit('reject-call', { to_sid: remoteSid });
    }
  };



  useEffect(() => { 
    if (activeConv) fetchMessages();
  }, [activeConv, fetchMessages]);

  // Periodic polling fallback for messages when WebSocket is closed/unsupported
  useEffect(() => {
    if (!activeConv) return;
    
    const interval = setInterval(() => {
      const isWsOpen = socketRef.current && socketRef.current.readyState === WebSocket.OPEN;
      if (!isWsOpen) {
        fetchMessages(true);
      }
    }, 4000);

    return () => clearInterval(interval);
  }, [activeConv, fetchMessages]);

  useEffect(() => { scrollRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);

  const handleSendMessage = async (e) => {
    if (e) e.preventDefault();
    if (!input.trim() || !activeConv) return;
    
    const textContent = input.trim();
    setInput('');

    // Use HTTP POST — the Django backend broadcasts via WebSocket channel layer automatically.
    // Do NOT also send via WebSocket here to avoid the sender seeing the message twice.
    const payload = { conversation: activeConv.id, content: textContent, message_type: 'TEXT' };
    try {
      const res = await api.post('/chat/messages/', payload);
      const formattedMsg = res.data.results || res.data;
      // Optimistically add own message immediately from REST response
      setMessages(prev => {
        if (prev.some(m => m.id === formattedMsg.id)) return prev;
        return [...prev, formattedMsg];
      });
      updateConvList(formattedMsg);
    } catch (err) {
      console.error("HTTP message send failed:", err);
      // Restore message to input if failed
      setInput(textContent);
      alert("Failed to send message. Please try again.");
    }
  };

  if (checkingFamily) {
    return (
      <div className="flex flex-col justify-center items-center h-96 space-y-4">
        <Loader2 className="w-12 h-12 animate-spin text-brand-500" />
        <p className="text-navy-400 font-medium">Securing connection to Family Circles...</p>
      </div>
    );
  }

  if (!hasFamily) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[400px] p-8 text-center space-y-6 max-w-md mx-auto bg-white rounded-3xl border border-navy-100 shadow-xl my-12 animate-in fade-in duration-300">
        <div className="w-20 h-20 bg-brand-500/10 rounded-full flex items-center justify-center text-brand-500">
          <Users className="w-10 h-10" />
        </div>
        <h3 className="text-2xl font-black text-navy-950">Join a Family Circle First</h3>
        <p className="text-navy-500 text-sm">
          To start using Family Chat, you must first create a Family Circle or join an existing one. Let's get you set up!
        </p>
        <a 
          href="/family" 
          className="w-full bg-brand-500 hover:bg-brand-600 text-white font-extrabold rounded-2xl py-4 flex items-center justify-center space-x-2 transition-all shadow-lg shadow-brand-500/20"
        >
          <span>Go to Family Directory</span>
        </a>
      </div>
    );
  }

  return (
    <div className="h-screen md:h-[calc(100vh-120px)] flex bg-white/50 md:backdrop-blur-xl md:rounded-[3rem] md:border border-white/20 shadow-2xl overflow-hidden animate-in fade-in zoom-in duration-500">
      {/* Sidebar - Hidden on mobile if chat is active */}
      <div className={`${activeConv ? 'hidden md:flex' : 'flex'} w-full md:w-[380px] border-r border-navy-100/50 flex-col bg-white/40 backdrop-blur-md`}>
        <div className="p-6 space-y-6">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-black text-navy-900">Chats</h2>
            <div className="flex items-center space-x-2">
              <button 
                onClick={handleOpenNewChat}
                className="p-2 bg-brand-500 hover:bg-brand-600 text-white rounded-full transition-colors shadow-sm flex items-center justify-center"
                title="New Chat"
              >
                <Plus className="w-4.5 h-4.5" />
              </button>
              <button className="p-2 hover:bg-navy-100 rounded-full transition-colors"><Archive className="w-5 h-5 text-navy-400" /></button>
            </div>
          </div>
          
          <div className="relative group">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-navy-400 group-focus-within:text-brand-500 transition-colors" />
            <input 
              type="text" 
              placeholder="Search family..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-navy-50/50 border-none rounded-2xl py-3 pl-12 pr-4 text-sm text-navy-900 focus:ring-2 focus:ring-brand-500/20 transition-all"
            />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto px-2 space-y-1">
          {conversations.filter(c => (c.name || c.participants_details?.[0]?.username || c.family_group_name)?.toLowerCase().includes(searchQuery.toLowerCase())).map(conv => {
            const name = conv.is_group ? (conv.name || conv.family_group_name) : conv.participants_details?.[0]?.username;
            const isTyping = Object.values(typingUsers[conv.id] || {}).some(v => v);
            const isOnline = !conv.is_group && onlineStatus[conv.participants?.[0]] === 'online';

            return (
              <div key={conv.id} onClick={() => setActiveConv(conv)} className={`group p-4 flex items-center rounded-[2rem] cursor-pointer transition-all ${activeConv?.id === conv.id ? 'bg-brand-500 text-white shadow-lg shadow-brand-500/30' : 'hover:bg-white/60 text-navy-900'}`}>
                <div className="relative">
                  <img src={conv.group_photo || conv.participants_details?.[0]?.profile_picture || `https://i.pravatar.cc/150?u=${conv.id}`} alt={name} className="w-14 h-14 rounded-2xl object-cover shadow-sm mr-4 bg-navy-100" />
                  {isOnline && <div className="absolute -top-1 -right-1 w-4 h-4 bg-emerald-500 border-4 border-white rounded-full"></div>}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex justify-between items-center mb-1">
                    <h4 className="font-bold truncate pr-2">{name || 'Family Chat'}</h4>
                    <span className={`text-[10px] ${activeConv?.id === conv.id ? 'opacity-70' : 'text-navy-400'}`}>{conv.latest_message ? new Date(conv.latest_message.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}</span>
                  </div>
                  <p className={`text-xs truncate flex items-center ${activeConv?.id === conv.id ? 'opacity-80' : 'text-navy-500'}`}>
                    {isTyping ? <span className="text-emerald-500 font-bold animate-pulse">typing...</span> : (
                      <>
                        {conv.latest_message?.sender === currentUser.id && (conv.latest_message.status === 'READ' ? <CheckCheck className="w-3 h-3 mr-1 text-blue-400" /> : <Check className="w-3 h-3 mr-1" />)}
                        {conv.latest_message?.content || 'Share a moment...'}
                      </>
                    )}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Main Chat Area - Full screen on mobile if active */}
      <div className={`${activeConv ? 'flex' : 'hidden md:flex'} flex-1 flex flex-col bg-white/20`}>
        {activeConv ? (
          <>
            <header className="h-24 px-4 md:px-8 border-b border-navy-100/30 flex items-center justify-between bg-white/40 backdrop-blur-md">
              <div className="flex items-center space-x-2 md:space-x-4">
                {/* Back Button for Mobile */}
                <button onClick={() => setActiveConv(null)} className="md:hidden p-2 hover:bg-navy-100 rounded-full transition-colors mr-1">
                  <X className="w-6 h-6 text-navy-600" />
                </button>
                
                <div className="relative">
                  <img src={activeConv.group_photo || activeConv.participants_details?.[0]?.profile_picture || `https://i.pravatar.cc/150?u=${activeConv.id}`} alt="User" className="w-10 h-10 md:w-12 md:h-12 rounded-2xl shadow-md border-2 border-white bg-navy-100" />
                  {onlineStatus[activeConv.participants?.[0]] === 'online' && <div className="absolute -bottom-1 -right-1 w-3 h-3 md:w-4 md:h-4 bg-emerald-500 border-4 border-white rounded-full"></div>}
                </div>
                <div>
                  <h3 className="text-base md:text-lg font-black text-navy-900 truncate max-w-[120px] md:max-w-none">{activeConv.is_group ? (activeConv.name || activeConv.family_group_name) : activeConv.participants_details?.[0]?.username}</h3>
                  <div className="text-[10px] md:text-xs font-bold text-navy-400">
                    {Object.values(typingUsers[activeConv.id] || {}).some(v => v) ? <span className="text-emerald-500 animate-pulse">typing...</span> : (onlineStatus[activeConv.participants?.[0]] === 'online' ? 'Online' : 'Active recently')}
                  </div>
                </div>
              </div>
            </header>

            <main className="flex-1 overflow-y-auto p-8 space-y-6">
              {loading ? <Loader2 className="w-8 h-8 text-brand-500 animate-spin mx-auto mt-20" /> : messages.map((msg, i) => (
                <MessageBubble 
                  key={msg.id || i} 
                  msg={msg} 
                  isMe={msg.sender === currentUser.id} 
                  onDelete={async (id) => {
                    if (!window.confirm("Delete this message?")) return;
                    try {
                      await api.delete(`/chat/messages/${id}/`);
                      setMessages(prev => prev.filter(m => m.id !== id));
                    } catch (err) {
                      console.error(err);
                      alert("Failed to delete message.");
                    }
                  }}
                />
              ))}
              <div ref={scrollRef} />
            </main>

            <footer className="p-8 bg-white/40 backdrop-blur-md relative">
              {showAttachments && <AttachmentMenu onSelect={(t) => { setShowAttachments(false); if (t === 'HEALTH') initiateCall('VIDEO'); }} onClose={() => setShowAttachments(false)} />}
              <form onSubmit={handleSendMessage} className="flex items-center space-x-4">
                <div className="flex-1 flex items-center bg-white border border-navy-100 rounded-[2rem] px-4 py-2 shadow-sm">
                  <button type="button" onClick={() => setShowAttachments(!showAttachments)} className={`p-2 rounded-full transition-all ${showAttachments ? 'bg-brand-500 text-white' : 'hover:bg-navy-50 text-navy-400'}`}><Paperclip className="w-5 h-5" /></button>
                  <input type="text" value={input} onChange={(e) => setInput(e.target.value)} placeholder="Message family..." className="flex-1 bg-transparent border-none focus:ring-0 text-navy-900 px-4 py-2 font-medium outline-none" />
                </div>
                <button type="submit" disabled={!input.trim()} className={`p-4 rounded-[1.5rem] transition-all shadow-xl ${input.trim() ? 'bg-brand-500 text-white shadow-brand-500/40' : 'bg-navy-100 text-navy-300'}`}><Send className="w-6 h-6" /></button>
              </form>
            </footer>
          </>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center space-y-4">
            <div className="w-32 h-32 bg-brand-500/10 rounded-full flex items-center justify-center animate-pulse"><Smile className="w-16 h-16 text-brand-500 opacity-20" /></div>
            <h3 className="text-2xl font-black text-navy-900">Your Family Connection</h3>
          </div>
        )}
      </div>

      {/* New Chat Modal */}
      {showNewChatModal && (
        <div className="fixed inset-0 bg-navy-950/80 backdrop-blur-sm z-[100] flex items-center justify-center p-4 animate-in fade-in duration-200">
          <div className="bg-white dark:bg-navy-900 rounded-[2.5rem] border border-navy-100 dark:border-navy-800 p-8 shadow-2xl max-w-md w-full relative animate-in zoom-in-95 duration-200">
            <button onClick={() => setShowNewChatModal(false)} className="absolute top-6 right-6 p-2 text-navy-400 hover:bg-navy-50 rounded-xl transition-colors">
              <X className="w-5 h-5" />
            </button>
            
            <div className="space-y-6">
              <div>
                <h3 className="text-2xl font-black text-navy-950 dark:text-white">Start a Conversation</h3>
                <p className="text-navy-500 dark:text-navy-400 text-xs mt-1">Select a family member or group circle to start messaging.</p>
              </div>

              {/* Family Circles Section */}
              <div className="space-y-3">
                <p className="text-xs font-black uppercase tracking-widest text-navy-400 flex items-center gap-1">
                  <Users className="w-3.5 h-3.5 text-brand-500" />
                  <span>Group Circles</span>
                </p>
                {familyGroups.length === 0 ? (
                  <p className="text-xs text-navy-400 font-medium">No active family groups found.</p>
                ) : (
                  <div className="max-h-36 overflow-y-auto space-y-2 pr-1">
                    {familyGroups.map(group => (
                      <button
                        key={group.id}
                        onClick={() => handleStartGroupChat(group.id, group.name)}
                        className="w-full p-3 flex items-center space-x-3 bg-navy-50 dark:bg-navy-800/40 hover:bg-brand-500 hover:text-white rounded-2xl text-left transition-all border border-transparent hover:border-brand-600 group"
                      >
                        <div className="w-9 h-9 bg-brand-100 dark:bg-brand-900/30 text-brand-600 rounded-xl flex items-center justify-center text-sm font-extrabold group-hover:bg-white/20 group-hover:text-white shrink-0">
                          {group.name?.charAt(0).toUpperCase()}
                        </div>
                        <div className="min-w-0">
                          <p className="text-sm font-extrabold text-navy-900 dark:text-white group-hover:text-white truncate">{group.name}</p>
                          <p className="text-[10px] text-navy-400 dark:text-navy-300 group-hover:text-white/85 truncate">{group.description || 'Family group chat'}</p>
                        </div>
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Family Members Section */}
              <div className="space-y-3">
                <p className="text-xs font-black uppercase tracking-widest text-navy-400 flex items-center gap-1">
                  <User className="w-3.5 h-3.5 text-brand-500" />
                  <span>Family Members</span>
                </p>
                {familyMembers.length === 0 ? (
                  <p className="text-xs text-navy-400 font-medium">No family members found.</p>
                ) : (
                  <div className="max-h-48 overflow-y-auto space-y-2 pr-1">
                    {familyMembers.map(member => (
                      <button
                        key={member.id}
                        onClick={() => handleStartPrivateChat(member.user)}
                        className="w-full p-3 flex items-center space-x-3 bg-navy-50 dark:bg-navy-800/40 hover:bg-brand-500 hover:text-white rounded-2xl text-left transition-all border border-transparent hover:border-brand-600 group"
                      >
                        <img
                          src={member.user_details.profile_picture || `https://i.pravatar.cc/150?u=${member.user}`}
                          alt={member.user_details.username}
                          className="w-9 h-9 rounded-xl object-cover shrink-0"
                        />
                        <div>
                          <p className="text-sm font-extrabold text-navy-900 dark:text-white group-hover:text-white">{member.user_details.username}</p>
                          <p className="text-[10px] text-navy-400 dark:text-navy-300 group-hover:text-white/85 capitalize">{member.label.toLowerCase()}</p>
                        </div>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
