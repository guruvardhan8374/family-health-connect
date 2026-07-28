import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class ChatScreen extends StatefulWidget {
  final int? initialFamilyGroupId;
  final String? initialFamilyGroupName;
  final int? targetUserId;
  final String? targetUsername;

  const ChatScreen({
    super.key,
    this.initialFamilyGroupId,
    this.initialFamilyGroupName,
    this.targetUserId,
    this.targetUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _conversationId;

  String _myUsername = '';
  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadUsernameAndFetch();
    _syncSubscription = SyncService.instance.stream.listen((event) {
      if (event['type'] == 'chat.message') {
        final data = event['data'];
        if (data != null && data['conversation_id'] == _conversationId) {
          final senderUsername = data['sender_username'] ?? 'Unknown';
          final messageId = data['id'];
          if (!_messages.any((m) => m['id'] == messageId)) {
            if (mounted) {
              setState(() {
                _messages.add({
                  'id': messageId,
                  'content': data['content'],
                  'sender_details': {'username': senderUsername},
                  'timestamp': data['timestamp'],
                });
              });
            }
          }
        }
      }
    });
  }

  Future<void> _loadUsernameAndFetch() async {
    final username = await AuthService.getUsername();
    _myUsername = username;
    _fetchChatData();
  }

  Future<void> _fetchChatData() async {
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    // 1. Target 1:1 user chat if specified — stop here, don't fall through
    if (widget.targetUserId != null) {
      final created = await ApiService.getOrCreatePrivateConversation(widget.targetUserId!);
      if (created != null && created['id'] != null) {
        _conversationId = created['id'];
        try {
          final msgs = await ApiService.getChatMessages(_conversationId!);
          if (mounted) {
            setState(() {
              _messages = msgs.reversed.toList();
              _isLoading = false;
            });
          }
        } catch (e) {
          if (mounted) setState(() { _isLoading = false; _errorMessage = 'Failed to load messages. Tap retry.'; });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Could not start chat with ${widget.targetUsername ?? 'this user'}. Please check your connection and try again.';
          });
        }
      }
      return; // Always return — don't fall through to group logic
    }

    // 2. Fetch conversations (group chat path)
    try {
      final conversations = await ApiService.getConversations(forceRefresh: true);
      
      // Check if initialFamilyGroupId was passed
      if (widget.initialFamilyGroupId != null) {
        final match = conversations.firstWhere(
          (c) => c['family_group'] == widget.initialFamilyGroupId || (c['family_group'] is Map && c['family_group']['id'] == widget.initialFamilyGroupId),
          orElse: () => null,
        );
        if (match != null) {
          _conversationId = match['id'];
        } else {
          final groupName = widget.initialFamilyGroupName ?? 'Family Circle';
          final created = await ApiService.getOrCreateFamilyGroupChat(widget.initialFamilyGroupId!, groupName);
          if (created != null && created['id'] != null) {
            _conversationId = created['id'];
          }
        }
      } else if (conversations.isNotEmpty) {
        _conversationId = conversations[0]['id'];
      } else {
        final groups = await ApiService.getFamilyGroups(forceRefresh: true);
        if (groups.isNotEmpty) {
          final group = groups[0];
          final created = await ApiService.getOrCreateFamilyGroupChat(group['id'], group['name'] ?? 'Family Group');
          if (created != null && created['id'] != null) {
            _conversationId = created['id'];
          }
        }
      }

      if (_conversationId != null) {
        final msgs = await ApiService.getChatMessages(_conversationId!);
        if (mounted) setState(() { _messages = msgs.reversed.toList(); _isLoading = false; });
      } else {
        if (mounted) setState(() { _isLoading = false; _errorMessage = 'No conversation found. Tap retry to try again.'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Connection error. Please check your network and tap retry.'; });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _conversationId == null) return;
    
    _controller.clear();
    // Optimistic UI update
    setState(() {
      _messages.add({
        'content': text,
        'sender_details': {'username': _myUsername},
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    await ApiService.sendMessage(_conversationId!, text);
    // Silent refresh
    _fetchChatData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.people_rounded, color: Color(0xFF14B8A6), size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.targetUsername != null && widget.targetUsername!.isNotEmpty
                  ? 'Chat with ${widget.targetUsername}'
                  : (widget.initialFamilyGroupName != null ? '${widget.initialFamilyGroupName} Group' : 'Family Group'),
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Text('Connected', style: TextStyle(color: Color(0xFF14B8A6), fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF14B8A6)),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchChatData();
            },
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
        : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 56, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      label: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: _fetchChatData,
                    ),
                  ],
                ),
              ),
            )
        : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                final senderDetails = msg['sender_details'] ?? {};
                final senderName = (senderDetails['username'] ?? 'Unknown').toString();
                final isMe = senderName == _myUsername;
                final text = (msg['content'] ?? '').toString();
                
                String timeStr = 'Now';
                if (msg['timestamp'] != null) {
                  try {
                    final dt = DateTime.parse(msg['timestamp'].toString()).toLocal();
                    timeStr = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                  } catch (_) {}
                }

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75),
                    child: Column(
                      crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 4),
                            child: Text(senderName,
                              style: TextStyle(color: Colors.grey[500], fontSize: 11,
                                fontWeight: FontWeight.bold)),
                          ),
                        GestureDetector(
                          onLongPress: () async {
                            final msgId = msg['id'];
                            if (msgId == null) return;
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Message'),
                                content: const Text('Are you sure you want to delete this message?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final success = await ApiService.deleteMessage(msgId);
                              if (success && mounted) {
                                setState(() {
                                  _messages.removeWhere((m) => m['id'] == msgId);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Message deleted')),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF14B8A6) : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMe ? 18 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 18),
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Text(text,
                              style: TextStyle(
                                color: isMe ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 14)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                          child: Text(timeStr,
                            style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }
}
