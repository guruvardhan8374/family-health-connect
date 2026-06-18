import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  int? _conversationId;

  String _myUsername = '';

  @override
  void initState() {
    super.initState();
    _loadUsernameAndFetch();
  }

  Future<void> _loadUsernameAndFetch() async {
    final username = await AuthService.getUsername();
    _myUsername = username;
    _fetchChatData();
  }

  Future<void> _fetchChatData() async {
    final conversations = await ApiService.getConversations();
    if (conversations.isNotEmpty) {
      _conversationId = conversations[0]['id'];
      final msgs = await ApiService.getChatMessages(_conversationId!);
      if (mounted) {
        setState(() {
          _messages = msgs.reversed.toList(); // Assuming API returns oldest first or we want newest at bottom
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Family Group', style: TextStyle(color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Connected', style: TextStyle(color: Color(0xFF14B8A6),
              fontSize: 11)),
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
                        Container(
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
    super.dispose();
  }
}
