import { useState, useEffect } from 'react';
import { 
  Mail, Phone, Video, MessageSquare, MoreVertical, ShieldCheck, Heart, 
  Plus, Loader2, Copy, Check, UserPlus, Users, Trash2, Award, 
  ArrowRight, X, ShieldAlert, Shield, HeartPulse, ExternalLink
} from 'lucide-react';
import api from '../utils/api';
import { useAuth } from '../contexts/AuthContext';
import { useSyncEvent } from '../contexts/SyncContext';

export default function FamilyDirectory() {
  const { user } = useAuth();
  const currentUserId = user?.id || parseInt(localStorage.getItem('user_id'));

  const [groups, setGroups] = useState([]);
  const [activeGroup, setActiveGroup] = useState(null);
  const [allMembers, setAllMembers] = useState([]);
  const [invitations, setInvitations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  
  // Modals & Forms
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showJoinModal, setShowJoinModal] = useState(false);
  const [copied, setCopied] = useState(false);

  // Form Fields
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteLabel, setInviteLabel] = useState('OTHER');
  const [newGroupName, setNewGroupName] = useState('');
  const [newGroupDesc, setNewGroupDesc] = useState('');
  const [joinCode, setJoinCode] = useState('');
  const [joinLabel, setJoinLabel] = useState('OTHER');

  // UI Control States
  const [activeDropdownId, setActiveDropdownId] = useState(null);
  const [activeTab, setActiveTab] = useState('directory'); // 'directory' or 'invitations'
  const [showCodeModal, setShowCodeModal] = useState(false);
  const [newGroupCode, setNewGroupCode] = useState({ code: '', name: '' });

  const fetchData = async () => {
    try {
      // 1. Fetch family groups the user is part of
      const groupsRes = await api.get('/family/groups/');
      const fetchedGroups = groupsRes.data.results || groupsRes.data || [];
      setGroups(fetchedGroups);

      if (fetchedGroups.length > 0) {
        // If there's no activeGroup or it's not in the fetched list, set first
        const currentActive = activeGroup 
          ? fetchedGroups.find(g => g.id === activeGroup.id) 
          : null;
        setActiveGroup(currentActive || fetchedGroups[0]);

        // 2. Fetch memberships
        const membersRes = await api.get('/family/members/');
        setAllMembers(membersRes.data.results || membersRes.data || []);

        // 3. Fetch invitations
        const invitesRes = await api.get('/family/invitations/');
        setInvitations(invitesRes.data.results || invitesRes.data || []);
      }
    } catch (err) {
      console.error('Failed to fetch family circle details:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  // ── Real-time sync: new family member joined from mobile ──────────────────
  useSyncEvent('family.update', () => {
    fetchData();
  }, []);

  const handleCopyCode = (code) => {
    if (!code) return;
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // Switch Active Group
  const handleSelectGroup = (groupId) => {
    const selected = groups.find(g => g.id === parseInt(groupId));
    if (selected) {
      setActiveGroup(selected);
      setActiveTab('directory');
      setActiveDropdownId(null);
    }
  };

  // Circle Administrator Check
  const isCurrentUserAdminOfActiveGroup = () => {
    if (!activeGroup) return false;
    const currentMember = allMembers.find(
      m => m.user === currentUserId && m.family_group === activeGroup.id
    );
    return currentMember?.is_admin || false;
  };

  // Filter members for active group
  const activeMembers = allMembers.filter(m => m.family_group === activeGroup?.id);

  // Group approved vs pending memberships
  const approvedMembers = activeMembers.filter(m => m.is_approved);
  const pendingMembers = activeMembers.filter(m => !m.is_approved);

  // --- API SUBMISSIONS ---

  const getErrorMessage = (err, defaultMsg) => {
    // If 401, the interceptor already handles redirect to /login — suppress the alert
    if (err.response?.status === 401) return null;
    if (err.response?.data) {
      const data = err.response.data;
      if (typeof data === 'string') return data;
      if (data.detail) return data.detail;
      if (data.error) return data.error;
      const firstFieldErr = Object.keys(data).map(key => {
        const val = data[key];
        return `${key}: ${Array.isArray(val) ? val.join(', ') : val}`;
      })[0];
      if (firstFieldErr) return firstFieldErr;
    }
    return err.message || defaultMsg;
  };

  const handleCreateGroup = async (e) => {
    e.preventDefault();
    if (!newGroupName.trim()) return;
    setSubmitting(true);
    try {
      const res = await api.post('/family/groups/', {
        name: newGroupName,
        description: newGroupDesc
      });
      const createdGroup = res.data;
      setNewGroupName('');
      setNewGroupDesc('');
      setShowCreateModal(false);
      await fetchData();
      // Show the family code in a modal — done after fetchData so state is settled
      if (createdGroup?.family_code) {
        setNewGroupCode({ code: createdGroup.family_code, name: createdGroup.name });
        setShowCodeModal(true);
      }
    } catch (err) {
      console.error(err);
      const msg = getErrorMessage(err, "Failed to create Family Circle");
      if (msg) alert(msg);
    } finally {
      setSubmitting(false);
    }
  };

  const handleJoinByCode = async (e) => {
    e.preventDefault();
    if (!joinCode.trim()) return;
    setSubmitting(true);
    try {
      const res = await api.post('/family/groups/join-by-code/', {
        family_code: joinCode.trim().toUpperCase(),
        label: joinLabel
      });
      setJoinCode('');
      setJoinLabel('OTHER');
      setShowJoinModal(false);
      await fetchData();
      alert(res.data.message || "Request submitted successfully!");
    } catch (err) {
      console.error(err);
      alert(getErrorMessage(err, "Invalid family code or failed to submit request"));
    } finally {
      setSubmitting(false);
    }
  };

  const handleSendInvite = async (e) => {
    e.preventDefault();
    if (!inviteEmail.trim() || !activeGroup) return;
    setSubmitting(true);
    try {
      await api.post(`/family/groups/${activeGroup.id}/invite/`, {
        email: inviteEmail.trim(),
        label: inviteLabel
      });
      setInviteEmail('');
      setInviteLabel('OTHER');
      setShowInviteModal(false);
      await fetchData();
      alert(`Invitation sent successfully to ${inviteEmail}!`);
    } catch (err) {
      console.error(err);
      alert(getErrorMessage(err, "Failed to send invitation"));
    } finally {
      setSubmitting(false);
    }
  };

  const handleApproveMember = async (membershipId) => {
    if (!window.confirm("Approve this membership request?")) return;
    try {
      await api.post(`/family/members/${membershipId}/approve/`);
      await fetchData();
      alert("Membership approved successfully!");
    } catch (err) {
      console.error(err);
      alert(getErrorMessage(err, "Failed to approve membership"));
    }
  };

  const handleRejectMember = async (membershipId) => {
    if (!window.confirm("Reject and delete this join request?")) return;
    try {
      await api.post(`/family/members/${membershipId}/reject/`);
      await fetchData();
      alert("Membership request rejected.");
    } catch (err) {
      console.error(err);
      alert(getErrorMessage(err, "Failed to reject request"));
    }
  };

  const handlePromoteAdmin = async (membershipId) => {
    if (!window.confirm("Promote this member to Admin? They will receive full permissions.")) return;
    try {
      await api.post(`/family/members/${membershipId}/promote-admin/`);
      setActiveDropdownId(null);
      await fetchData();
      alert("Member promoted to Admin!");
    } catch (err) {
      console.error(err);
      alert(getErrorMessage(err, "Failed to promote member"));
    }
  };

  const handleDemoteAdmin = async (membershipId) => {
    if (!window.confirm("Demote this member from Admin?")) return;
    try {
      await api.post(`/family/members/${membershipId}/demote-admin/`);
      setActiveDropdownId(null);
      await fetchData();
      alert("Member demoted successfully.");
    } catch (err) {
      console.error(err);
      alert(getErrorMessage(err, "Failed to demote member"));
    }
  };


  const handleUpdateRole = async (membershipId) => {
    const newRole = window.prompt(
      "Enter new relationship role:\nPARENT, CHILD, ELDER, SPOUSE, OTHER"
    );
    if (!newRole) return;
    const formattedRole = newRole.trim().toUpperCase();
    if (!['PARENT', 'CHILD', 'ELDER', 'SPOUSE', 'OTHER'].includes(formattedRole)) {
      alert("Invalid role choice.");
      return;
    }

    try {
      await api.patch(`/family/members/${membershipId}/`, {
        label: formattedRole
      });
      setActiveDropdownId(null);
      await fetchData();
      alert("Relationship role updated!");
    } catch (err) {
      console.error(err);
      alert("Failed to update role");
    }
  };

  const handleDeleteMember = async (membershipId) => {
    if (!window.confirm("Are you sure you want to remove this member from the Family Circle?")) return;
    try {
      await api.delete(`/family/members/${membershipId}/`);
      setActiveDropdownId(null);
      await fetchData();
      alert("Member removed from circle successfully.");
    } catch (err) {
      console.error(err);
      alert("Failed to delete member");
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col justify-center items-center h-96 space-y-4">
        <Loader2 className="w-12 h-12 animate-spin text-brand-500" />
        <p className="text-navy-400 font-medium">Securing connection to Family Circles...</p>
      </div>
    );
  }

  // --- RENDER 1: NO FAMILY CIRCLES (ONBOARDING VIEW) ---
  if (groups.length === 0) {
    return (
      <div className="max-w-5xl mx-auto space-y-12 py-12 px-4">
        <div className="text-center space-y-4">
          <div className="inline-flex p-4 bg-brand-500/10 rounded-full border border-brand-500/20 text-brand-500 mb-2">
            <Users className="w-10 h-10" />
          </div>
          <h1 className="text-4xl font-extrabold tracking-tight text-navy-950">Welcome to Family Connect</h1>
          <p className="text-lg text-navy-500 max-w-2xl mx-auto">
            Create a highly secure digital circle to keep your family connected, share vitals, monitor geofenced safe zones, and trigger fast emergency assistance.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          {/* Card A: Create Family Circle */}
          <div className="bg-white rounded-[2.5rem] border border-navy-100 p-8 shadow-xl relative overflow-hidden group hover:border-brand-300 transition-all duration-300 flex flex-col justify-between">
            <div className="space-y-6">
              <div className="w-12 h-12 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-500 flex items-center justify-center">
                <Plus className="w-6 h-6" />
              </div>
              <div>
                <h3 className="text-2xl font-black text-navy-950">Create a New Circle</h3>
                <p className="text-navy-500 mt-2">Become the Family Head. Initialize a customized circle and invite your loved ones.</p>
              </div>
              <form onSubmit={handleCreateGroup} className="space-y-4 pt-4">
                <div>
                  <label className="block text-xs font-black uppercase text-navy-400 tracking-wider mb-2">Circle Name</label>
                  <input 
                    type="text" 
                    placeholder="e.g. Smith Family Hub"
                    value={newGroupName}
                    onChange={(e) => setNewGroupName(e.target.value)}
                    required
                    className="w-full bg-navy-50/50 border border-navy-100 rounded-2xl py-3 px-4 text-sm text-navy-950 focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 outline-none transition-all"
                  />
                </div>
                <div>
                  <label className="block text-xs font-black uppercase text-navy-400 tracking-wider mb-2">Description (Optional)</label>
                  <textarea 
                    placeholder="Brief description of this family..."
                    value={newGroupDesc}
                    onChange={(e) => setNewGroupDesc(e.target.value)}
                    rows={2}
                    className="w-full bg-navy-50/50 border border-navy-100 rounded-2xl py-3 px-4 text-sm text-navy-950 focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 outline-none transition-all resize-none"
                  />
                </div>
                <button type="submit" className="w-full mt-2 bg-emerald-500 hover:bg-emerald-600 text-white font-extrabold rounded-2xl py-4 flex items-center justify-center space-x-2 transition-all shadow-lg shadow-emerald-500/20">
                  {submitting ? <Loader2 className="w-5 h-5 animate-spin" /> : <><span>Launch Family Circle</span><ArrowRight className="w-5 h-5" /></>}
                </button>
              </form>
            </div>
          </div>

          {/* Card B: Join Existing Circle */}
          <div className="bg-white rounded-[2.5rem] border border-navy-100 p-8 shadow-xl relative overflow-hidden group hover:border-brand-300 transition-all duration-300 flex flex-col justify-between">
            <div className="space-y-6">
              <div className="w-12 h-12 rounded-2xl bg-brand-500/10 border border-brand-500/20 text-brand-500 flex items-center justify-center">
                <UserPlus className="w-6 h-6" />
              </div>
              <div>
                <h3 className="text-2xl font-black text-navy-950">Join an Existing Circle</h3>
                <p className="text-navy-500 mt-2">Enter a unique invite code shared by your Family Head to request access.</p>
              </div>
              <form onSubmit={handleJoinByCode} className="space-y-4 pt-4">
                <div>
                  <label className="block text-xs font-black uppercase text-navy-400 tracking-wider mb-2">Invite Code</label>
                  <input 
                    type="text" 
                    placeholder="e.g. FAM-89A1-BC"
                    value={joinCode}
                    onChange={(e) => setJoinCode(e.target.value)}
                    required
                    className="w-full bg-navy-50/50 border border-navy-100 rounded-2xl py-3 px-4 text-sm font-semibold tracking-wider text-navy-950 placeholder-navy-300 focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 outline-none transition-all uppercase"
                  />
                </div>
                <div>
                  <label className="block text-xs font-black uppercase text-navy-400 tracking-wider mb-2">Your Relationship Role</label>
                  <select 
                    value={joinLabel}
                    onChange={(e) => setJoinLabel(e.target.value)}
                    className="w-full bg-navy-50/50 border border-navy-100 rounded-2xl py-3 px-4 text-sm text-navy-950 focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 outline-none transition-all"
                  >
                    <option value="PARENT">Parent</option>
                    <option value="CHILD">Child</option>
                    <option value="ELDER">Elder</option>
                    <option value="SPOUSE">Spouse</option>
                    <option value="OTHER">Other</option>
                  </select>
                </div>
                <button type="submit" className="w-full mt-2 bg-brand-500 hover:bg-brand-600 text-white font-extrabold rounded-2xl py-4 flex items-center justify-center space-x-2 transition-all shadow-lg shadow-brand-500/20">
                  {submitting ? <Loader2 className="w-5 h-5 animate-spin" /> : <><span>Send Join Request</span><ArrowRight className="w-5 h-5" /></>}
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // --- RENDER 2: DASHBOARD VIEW (HAS FAMILY CIRCLES) ---
  const isCircleAdmin = isCurrentUserAdminOfActiveGroup();

  return (
    <div className="space-y-8 pb-16 max-w-7xl mx-auto px-4">
      {/* Top Banner Circle Info / Selector */}
      <header className="flex flex-col lg:flex-row lg:items-center justify-between gap-6 bg-white rounded-[2.5rem] border border-navy-100 p-8 shadow-sm">
        <div className="space-y-4">
          <div className="flex items-center space-x-3">
            <label className="text-xs font-black uppercase text-navy-400 tracking-widest block">Active Circle:</label>
            <select 
              value={activeGroup?.id || ''}
              onChange={(e) => handleSelectGroup(e.target.value)}
              className="bg-navy-50 border-none rounded-xl py-1.5 px-3 text-sm font-extrabold text-navy-900 focus:ring-2 focus:ring-brand-500/20 cursor-pointer outline-none"
            >
              {groups.map(g => (
                <option key={g.id} value={g.id}>{g.name}</option>
              ))}
            </select>
          </div>
          <div>
            <h1 className="text-3xl font-extrabold text-navy-950 tracking-tight">{activeGroup?.name}</h1>
            <p className="text-navy-500 text-sm mt-1">{activeGroup?.description || 'A securely connected family circle sharing medical metrics and location assistance.'}</p>
          </div>
        </div>

        {/* Invite Code & Utility controls */}
        <div className="flex flex-wrap items-center gap-4">
          {activeGroup?.family_code && (
            <div className="bg-navy-50/70 border border-navy-100 rounded-3xl p-4 flex items-center space-x-4">
              <div>
                <span className="text-[10px] font-black uppercase text-navy-400 tracking-widest block">Invite/Join Code</span>
                <span className="text-base font-extrabold text-navy-900 tracking-wider font-mono">{activeGroup.family_code}</span>
              </div>
              <button 
                onClick={() => handleCopyCode(activeGroup.family_code)} 
                className={`p-2.5 rounded-2xl border transition-all ${copied ? 'bg-emerald-500 border-emerald-500 text-white' : 'bg-white hover:bg-navy-100 border-navy-100 text-navy-600'}`}
                title="Copy Invite Code"
              >
                {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
              </button>
            </div>
          )}

          {/* New Circle & Join Actions */}
          <div className="flex items-center space-x-2">
            <button 
              onClick={() => setShowJoinModal(true)} 
              className="px-5 py-3 border border-navy-100 bg-white hover:bg-navy-50 text-navy-950 font-bold rounded-2xl text-sm transition-all flex items-center space-x-2"
            >
              <UserPlus className="w-4 h-4 text-navy-500" />
              <span>Join Another</span>
            </button>
            <button 
              onClick={() => setShowCreateModal(true)} 
              className="px-5 py-3 bg-brand-500 hover:bg-brand-600 text-white font-bold rounded-2xl text-sm transition-all flex items-center space-x-2 shadow-sm"
            >
              <Plus className="w-4 h-4" />
              <span>New Circle</span>
            </button>
          </div>
        </div>
      </header>

      {/* Admin Sub-Navigation (Directory vs Invitations/Requests) */}
      <div className="flex items-center justify-between border-b border-navy-100 pb-2">
        <div className="flex space-x-6 text-sm">
          <button 
            onClick={() => setActiveTab('directory')}
            className={`pb-3 font-extrabold tracking-wide uppercase transition-all border-b-2 ${activeTab === 'directory' ? 'border-brand-500 text-brand-600' : 'border-transparent text-navy-400 hover:text-navy-700'}`}
          >
            Directory ({approvedMembers.length})
          </button>
          {isCircleAdmin && (
            <button 
              onClick={() => setActiveTab('invitations')}
              className={`pb-3 font-extrabold tracking-wide uppercase transition-all border-b-2 flex items-center space-x-2 ${activeTab === 'invitations' ? 'border-brand-500 text-brand-600' : 'border-transparent text-navy-400 hover:text-navy-700'}`}
            >
              <span>Management Portal</span>
              {(pendingMembers.length > 0) && (
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500 animate-pulse"></span>
              )}
            </button>
          )}
        </div>
      </div>

      {/* --- TAB CONTENT 1: MAIN MEMBERS DIRECTORY GRID --- */}
      {activeTab === 'directory' && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {approvedMembers.map((membership) => {
            const isMe = membership.user === currentUserId;
            const userDetails = membership.user_details || {};
            const relationshipLabel = membership.label || 'OTHER';

            return (
              <div 
                key={membership.id} 
                className="bg-white rounded-[2.5rem] border border-navy-100 shadow-sm overflow-hidden hover:shadow-xl transition-all duration-300 flex flex-col justify-between group"
              >
                <div className="p-8 pb-4">
                  <div className="flex justify-between items-start mb-6">
                    {/* User Profile Image */}
                    <div className="relative">
                      <img 
                        src={userDetails.profile_picture || `https://i.pravatar.cc/150?u=${membership.user}`} 
                        alt={userDetails.username || 'User'} 
                        className="w-20 h-20 rounded-3xl object-cover border-4 border-navy-50 shadow-sm bg-navy-100" 
                      />
                      {membership.is_admin ? (
                        <div className="absolute -bottom-2 -right-2 bg-brand-500 text-white p-1.5 rounded-xl border-4 border-white shadow-sm" title="Family Administrator">
                          <Award className="w-3 h-3" />
                        </div>
                      ) : (
                        <div className="absolute -bottom-2 -right-2 bg-emerald-500 text-white p-1.5 rounded-xl border-4 border-white shadow-sm" title="Secured Member">
                          <ShieldCheck className="w-3 h-3" />
                        </div>
                      )}
                    </div>

                    {/* Admin Dropdown Actions Trigger */}
                    {isCircleAdmin && !isMe && (
                      <div className="relative">
                        <button 
                          onClick={() => setActiveDropdownId(activeDropdownId === membership.id ? null : membership.id)}
                          className="p-2 text-navy-400 hover:bg-navy-50 rounded-xl transition-colors"
                        >
                          <MoreVertical className="w-5 h-5" />
                        </button>
                        
                        {/* Dropdown Options Box */}
                        {activeDropdownId === membership.id && (
                          <div className="absolute right-0 mt-2 w-48 bg-white border border-navy-100 rounded-2xl shadow-xl z-50 py-2 animate-in fade-in slide-in-from-top-2 duration-200">
                            <button 
                              onClick={() => handleUpdateRole(membership.id)} 
                              className="w-full text-left px-4 py-2 text-sm text-navy-700 hover:bg-navy-50 transition-colors"
                            >
                              Modify Role Label
                            </button>
                            {membership.is_admin ? (
                              <button 
                                onClick={() => handleDemoteAdmin(membership.id)} 
                                className="w-full text-left px-4 py-2 text-sm text-navy-700 hover:bg-navy-50 transition-colors"
                              >
                                Demote from Admin
                              </button>
                            ) : (
                              <button 
                                onClick={() => handlePromoteAdmin(membership.id)} 
                                className="w-full text-left px-4 py-2 text-sm text-navy-700 hover:bg-navy-50 transition-colors"
                              >
                                Promote to Admin
                              </button>
                            )}
                            <div className="border-t border-navy-100 my-1"></div>
                            <button 
                              onClick={() => handleDeleteMember(membership.id)} 
                              className="w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-red-50 transition-colors flex items-center space-x-2"
                            >
                              <Trash2 className="w-4 h-4" />
                              <span>Remove from Circle</span>
                            </button>
                          </div>
                        )}
                      </div>
                    )}
                  </div>

                  <h3 className="text-xl font-extrabold text-navy-950 mb-1 flex items-center gap-2">
                    <span>{userDetails.username || 'Anonymous Member'}</span>
                    {isMe && (
                      <span className="text-[10px] font-black uppercase bg-navy-100 text-navy-500 px-2 py-0.5 rounded-lg">You</span>
                    )}
                  </h3>
                  
                  {/* Badge Row */}
                  <div className="flex flex-wrap items-center gap-2 mb-6">
                    <span className="text-[10px] font-extrabold uppercase tracking-wider text-brand-600 bg-brand-50 px-2 py-1 rounded-lg">
                      {relationshipLabel}
                    </span>
                    <span className="text-[10px] font-extrabold uppercase tracking-wider text-navy-500 bg-navy-50 px-2 py-1 rounded-lg">
                      {membership.is_admin ? 'Admin' : 'Member'}
                    </span>
                  </div>

                  {/* Vitals & Information */}
                  <div className="space-y-3 mb-6 text-sm text-navy-600">
                    <div className="flex items-center">
                      <Mail className="w-4 h-4 mr-3 text-navy-400 shrink-0" />
                      <span className="truncate">{userDetails.email || 'No email registered'}</span>
                    </div>
                    <div className="flex items-center">
                      <Phone className="w-4 h-4 mr-3 text-navy-400 shrink-0" />
                      <span>{userDetails.phone_number || 'No phone number'}</span>
                    </div>
                  </div>
                </div>

                {/* Bottom Card Contacts Bar */}
                <div className="px-8 py-5 bg-navy-50/40 flex justify-between items-center border-t border-navy-100">
                  <div className="flex space-x-2">
                    <a 
                      href={`/chat`}
                      title="Send Message" 
                      className="p-3 bg-white text-navy-600 rounded-2xl hover:bg-brand-500 hover:text-white transition-all shadow-sm border border-navy-100/50"
                    >
                      <MessageSquare className="w-4 h-4" />
                    </a>
                    {userDetails.phone_number && (
                      <a 
                        href={`tel:${userDetails.phone_number}`}
                        title="Voice Call" 
                        className="p-3 bg-white text-navy-600 rounded-2xl hover:bg-brand-500 hover:text-white transition-all shadow-sm border border-navy-100/50"
                      >
                        <Phone className="w-4 h-4" />
                      </a>
                    )}
                  </div>
                  
                  <a 
                    href={`/health`}
                    className="flex items-center space-x-2 bg-white px-4 py-2 rounded-2xl border border-navy-100 text-xs font-black text-navy-950 hover:border-brand-500 transition-all shadow-sm"
                  >
                    <HeartPulse className="w-4 h-4 text-rose-500" />
                    <span>Health Records</span>
                  </a>
                </div>
              </div>
            );
          })}

          {/* Quick Invite Box */}
          {isCircleAdmin && (
            <button 
              onClick={() => setShowInviteModal(true)}
              className="bg-navy-50/30 rounded-[2.5rem] border-2 border-dashed border-navy-200 flex flex-col items-center justify-center p-12 hover:border-brand-500 hover:bg-brand-50/20 transition-all group min-h-[300px]"
            >
              <div className="w-14 h-14 bg-white rounded-3xl flex items-center justify-center mb-4 shadow-sm group-hover:scale-110 transition-transform">
                <UserPlus className="w-6 h-6 text-brand-500" />
              </div>
              <h3 className="text-lg font-extrabold text-navy-900 mb-1">Invite Family Member</h3>
              <p className="text-navy-400 text-xs text-center max-w-[200px]">Add immediate family to this circle via email</p>
            </button>
          )}
        </div>
      )}

      {/* --- TAB CONTENT 2: PORTAL ADMINISTRATION (PENDING REQUESTS & INVITES) --- */}
      {activeTab === 'invitations' && isCircleAdmin && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12">
          {/* Section A: Pending Approvals */}
          <div className="space-y-6 bg-white rounded-[2.5rem] border border-navy-100 p-8 shadow-sm">
            <div>
              <h2 className="text-2xl font-black text-navy-950 flex items-center gap-2">
                <ShieldAlert className="w-6 h-6 text-amber-500" />
                <span>Pending Join Requests ({pendingMembers.length})</span>
              </h2>
              <p className="text-navy-500 text-xs mt-1">Review requests from users trying to join using your invite code.</p>
            </div>
            
            <div className="border-t border-navy-100 my-4"></div>

            {pendingMembers.length === 0 ? (
              <div className="text-center py-12 space-y-2">
                <Shield className="w-8 h-8 text-navy-300 mx-auto" />
                <p className="text-navy-400 text-sm font-semibold">No pending circle requests</p>
              </div>
            ) : (
              <div className="space-y-4">
                {pendingMembers.map((req) => (
                  <div key={req.id} className="bg-navy-50/50 rounded-3xl border border-navy-100 p-6 flex flex-col md:flex-row md:items-center justify-between gap-4">
                    <div className="flex items-center space-x-3">
                      <img src={req.user_details?.profile_picture || `https://i.pravatar.cc/150?u=${req.user}`} className="w-12 h-12 rounded-xl object-cover" />
                      <div>
                        <h4 className="font-extrabold text-navy-950">{req.user_details?.username}</h4>
                        <span className="text-[10px] font-black uppercase text-brand-600 bg-brand-50 px-2 py-0.5 rounded-lg inline-block mt-0.5">Role requested: {req.label}</span>
                      </div>
                    </div>
                    <div className="flex items-center space-x-2">
                      <button 
                        onClick={() => handleRejectMember(req.id)}
                        className="px-4 py-2 border border-red-200 hover:bg-red-50 text-red-600 font-bold rounded-xl text-xs transition-colors"
                      >
                        Reject
                      </button>
                      <button 
                        onClick={() => handleApproveMember(req.id)}
                        className="px-4 py-2 bg-emerald-500 hover:bg-emerald-600 text-white font-bold rounded-xl text-xs transition-colors shadow-sm"
                      >
                        Approve
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Section B: Sent Invitations */}
          <div className="space-y-6 bg-white rounded-[2.5rem] border border-navy-100 p-8 shadow-sm">
            <div className="flex justify-between items-center">
              <div>
                <h2 className="text-2xl font-black text-navy-950">Active Sent Invites ({invitations.filter(i => i.family_group === activeGroup?.id).length})</h2>
                <p className="text-navy-500 text-xs mt-1">Track emails you sent invitations to.</p>
              </div>
              <button 
                onClick={() => setShowInviteModal(true)}
                className="p-2 bg-brand-500 hover:bg-brand-600 text-white rounded-xl transition-all shadow-sm"
                title="Send Invite Email"
              >
                <Plus className="w-4 h-4" />
              </button>
            </div>

            <div className="border-t border-navy-100 my-4"></div>

            {invitations.filter(i => i.family_group === activeGroup?.id).length === 0 ? (
              <div className="text-center py-12 space-y-2">
                <Mail className="w-8 h-8 text-navy-300 mx-auto" />
                <p className="text-navy-400 text-sm font-semibold">No active pending email invites</p>
              </div>
            ) : (
              <div className="space-y-4">
                {invitations.filter(i => i.family_group === activeGroup?.id).map((inv) => (
                  <div key={inv.id} className="bg-navy-50/50 rounded-3xl border border-navy-100 p-4 flex justify-between items-center">
                    <div className="min-w-0">
                      <h4 className="font-extrabold text-navy-950 truncate text-sm">{inv.invited_email}</h4>
                      <div className="flex items-center space-x-2 mt-1">
                        <span className={`text-[10px] font-black px-2 py-0.5 rounded-lg uppercase ${inv.status === 'PENDING' ? 'bg-amber-100 text-amber-600' : (inv.status === 'ACCEPTED' ? 'bg-emerald-100 text-emerald-600' : 'bg-navy-100 text-navy-500')}`}>
                          {inv.status}
                        </span>
                        <span className="text-[10px] text-navy-400 font-medium">Expires {new Date(inv.expires_at).toLocaleDateString()}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* --- DIALOG MODALS --- */}

      {/* 1. Modal: Invite by Email */}
      {showInviteModal && activeGroup && (
        <div className="fixed inset-0 bg-navy-950/80 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
          <div className="bg-white rounded-[2.5rem] border border-navy-100 p-8 shadow-2xl max-w-md w-full relative animate-in zoom-in-95 duration-200">
            <button onClick={() => setShowInviteModal(false)} className="absolute top-6 right-6 p-2 text-navy-400 hover:bg-navy-50 rounded-xl transition-colors">
              <X className="w-5 h-5" />
            </button>
            <div className="space-y-6">
              <div>
                <h3 className="text-2xl font-black text-navy-950">Invite Family Member</h3>
                <p className="text-navy-500 text-xs mt-1">They will receive a secure token to bypass request approval processes.</p>
              </div>
              <form onSubmit={handleSendInvite} className="space-y-4">
                <div>
                  <label className="block text-xs font-black uppercase text-navy-400 tracking-wider mb-2">Email Address</label>
                  <input 
                    type="email" 
                    placeholder="name@email.com"
                    value={inviteEmail}
                    onChange={(e) => setInviteEmail(e.target.value)}
                    required
                    className="w-full bg-navy-50/50 border border-navy-100 rounded-2xl py-3 px-4 text-sm text-navy-950 focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 outline-none transition-all"
                  />
                </div>
                <div>
                  <label className="block text-xs font-black uppercase text-navy-400 tracking-wider mb-2">Relationship Role</label>
                  <select 
                    value={inviteLabel}
                    onChange={(e) => setInviteLabel(e.target.value)}
                    className="w-full bg-navy-50/50 border border-navy-100 rounded-2xl py-3 px-4 text-sm text-navy-950 focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 outline-none transition-all"
                  >
                    <option value="PARENT">Parent</option>
                    <option value="CHILD">Child</option>
                    <option value="ELDER">Elder</option>
                    <option value="SPOUSE">Spouse</option>
                    <option value="OTHER">Other</option>
                  </select>
                </div>
                <button type="submit" className="w-full bg-brand-500 hover:bg-brand-600 text-white font-extrabold rounded-2xl py-4 flex items-center justify-center space-x-2 transition-all shadow-md">
                  {submitting ? <Loader2 className="w-5 h-5 animate-spin" /> : <><span>Send Secure Invitation</span><ArrowRight className="w-5 h-5" /></>}
                </button>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* 2. Modal: Create Family Circle */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-navy-950/80 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
          <div className="bg-white rounded-[2.5rem] border border-navy-100 p-8 shadow-2xl max-w-md w-full relative animate-in zoom-in-95 duration-200">
            <button onClick={() => setShowCreateModal(false)} className="absolute top-6 right-6 p-2 text-navy-400 hover:bg-navy-50 rounded-xl transition-colors">
              <X className="w-5 h-5" />
            </button>
            <div className="space-y-6">
              <div>
                <h3 className="text-2xl font-black text-navy-950">New Family Circle</h3>
                <p className="text-navy-500 text-xs mt-1">Spin up a brand new microcircle. You will automatically be assigned as Admin.</p>
              </div>
              <form onSubmit={handleCreateGroup} className="space-y-4">
                <div>
                  <label className="block text-xs font-black uppercase text-navy-400 tracking-wider mb-2">Circle Name</label>
                  <input 
                    type="text" 
                    placeholder="e.g. Miller Family Hub"
                    value={newGroupName}
                    onChange={(e) => setNewGroupName(e.target.value)}
                    required
                    className="w-full bg-navy-50/50 border border-navy-100 rounded-2xl py-3 px-4 text-sm text-navy-950 focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 outline-none transition-all"
                  />
                </div>
                <div>
                  <label className="block text-xs font-black uppercase text-navy-400 tracking-wider mb-2">Description (Optional)</label>
                  <textarea 
                    placeholder="Say something about this microcircle..."
                    value={newGroupDesc}
                    onChange={(e) => setNewGroupDesc(e.target.value)}
                    rows={2}
                    className="w-full bg-navy-50/50 border border-navy-100 rounded-2xl py-3 px-4 text-sm text-navy-950 focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 outline-none transition-all resize-none"
                  />
                </div>
                <button type="submit" className="w-full bg-emerald-500 hover:bg-emerald-600 text-white font-extrabold rounded-2xl py-4 flex items-center justify-center space-x-2 transition-all shadow-md">
                  {submitting ? <Loader2 className="w-5 h-5 animate-spin" /> : <><span>Create Circle</span><ArrowRight className="w-5 h-5" /></>}
                </button>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* 3. Modal: Join Circle by Code */}
      {showJoinModal && (
        <div className="fixed inset-0 bg-navy-950/80 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
          <div className="bg-white rounded-[2.5rem] border border-navy-100 p-8 shadow-2xl max-w-md w-full relative animate-in zoom-in-95 duration-200">
            <button onClick={() => setShowJoinModal(false)} className="absolute top-6 right-6 p-2 text-navy-400 hover:bg-navy-50 rounded-xl transition-colors">
              <X className="w-5 h-5" />
            </button>
            <div className="space-y-6">
              <div>
                <h3 className="text-2xl font-black text-navy-950">Join Family Circle</h3>
                <p className="text-navy-500 text-xs mt-1">Enter a family code to submit a join request. An administrator must approve it.</p>
              </div>
              <form onSubmit={handleJoinByCode} className="space-y-4">
                <div>
                  <label className="block text-xs font-black uppercase text-navy-400 tracking-wider mb-2">Invite Code</label>
                  <input 
                    type="text" 
                    placeholder="e.g. FAM-E342-CD"
                    value={joinCode}
                    onChange={(e) => setJoinCode(e.target.value)}
                    required
                    className="w-full bg-navy-50/50 border border-navy-100 rounded-2xl py-3 px-4 text-sm text-navy-950 focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 outline-none transition-all uppercase font-semibold"
                  />
                </div>
                <div>
                  <label className="block text-xs font-black uppercase text-navy-400 tracking-wider mb-2">Your Relationship Role</label>
                  <select 
                    value={joinLabel}
                    onChange={(e) => setJoinLabel(e.target.value)}
                    className="w-full bg-navy-50/50 border border-navy-100 rounded-2xl py-3 px-4 text-sm text-navy-950 focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 outline-none transition-all"
                  >
                    <option value="PARENT">Parent</option>
                    <option value="CHILD">Child</option>
                    <option value="ELDER">Elder</option>
                    <option value="SPOUSE">Spouse</option>
                    <option value="OTHER">Other</option>
                  </select>
                </div>
                <button type="submit" className="w-full bg-brand-500 hover:bg-brand-600 text-white font-extrabold rounded-2xl py-4 flex items-center justify-center space-x-2 transition-all shadow-md">
                  {submitting ? <Loader2 className="w-5 h-5 animate-spin" /> : <><span>Send Join Request</span><ArrowRight className="w-5 h-5" /></>}
                </button>
              </form>
            </div>
          </div>
        </div>
      )}
      {/* 4. Modal: Family Code Reveal */}
      {showCodeModal && (
        <div className="fixed inset-0 bg-navy-950/80 backdrop-blur-sm z-[200] flex items-center justify-center p-4">
          <div className="bg-white rounded-[2.5rem] border border-navy-100 p-10 shadow-2xl max-w-md w-full text-center animate-in zoom-in-95 duration-200">
            <div className="inline-flex p-4 bg-emerald-500/10 rounded-full border border-emerald-500/20 text-emerald-500 mb-6">
              <svg xmlns="http://www.w3.org/2000/svg" className="w-10 h-10" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
              </svg>
            </div>
            <h3 className="text-2xl font-black text-navy-950 mb-2">🎉 Circle Created!</h3>
            <p className="text-navy-500 text-sm mb-6">
              Share this code with family members so they can join <strong className="text-navy-900">{newGroupCode.name}</strong>:
            </p>
            <div className="bg-navy-50 border-2 border-dashed border-brand-300 rounded-2xl p-6 mb-6">
              <p className="text-4xl font-black tracking-[0.3em] text-brand-600 font-mono">{newGroupCode.code}</p>
            </div>
            <button
              onClick={() => {
                navigator.clipboard.writeText(newGroupCode.code);
                setCopied(true);
                setTimeout(() => setCopied(false), 2000);
              }}
              className={`w-full mb-3 py-4 rounded-2xl font-extrabold text-sm transition-all flex items-center justify-center space-x-2 ${
                copied
                  ? 'bg-emerald-500 text-white'
                  : 'bg-brand-500 hover:bg-brand-600 text-white shadow-md shadow-brand-500/20'
              }`}
            >
              {copied ? (
                <><Check className="w-4 h-4" /><span>Copied!</span></>
              ) : (
                <><Copy className="w-4 h-4" /><span>Copy Join Code</span></>
              )}
            </button>
            <button
              onClick={() => setShowCodeModal(false)}
              className="w-full py-3 rounded-2xl font-bold text-sm text-navy-500 hover:bg-navy-50 transition-all"
            >
              Done
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
