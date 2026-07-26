import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  // Only show SOS/Emergency notifications — all other types are hidden
  final String _selectedTab = 'EMERGENCY';
  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _listenToRealtimeEvents();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final String? typeFilter = _selectedTab == 'UNREAD' || _selectedTab == 'ALL' ? null : _selectedTab;
      final results = await ApiService.getNotifications(type: typeFilter);
      final count = await ApiService.getUnreadNotificationCount();

      if (mounted) {
        setState(() {
          _notifications = results;
          _unreadCount = count;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToRealtimeEvents() {
    _syncSub = SyncService.instance.stream.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'notification.new') {
        final data = event['data'] as Map<String, dynamic>?;
        if (data == null || data['id'] == null) return;
        // Only add SOS/Emergency notifications
        final nType = (data['type'] ?? '').toString().toUpperCase();
        if (nType != 'EMERGENCY' && nType != 'SOS') return;
        setState(() {
          _unreadCount++;
          _notifications.insert(0, {
            'id': data['id'],
            'type': data['type'] ?? 'EMERGENCY',
            'title': data['title'] ?? 'SOS Alert',
            'message': data['message'] ?? '',
            'priority': data['priority'] ?? 'HIGH',
            'is_read': false,
            'data': data['data'] ?? {},
            'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
            'created_at_formatted': 'Just now',
          });
        });
      }
    });
  }

  Future<void> _markAsRead(int id) async {
    final success = await ApiService.markNotificationAsRead(id);
    if (success && mounted) {
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == id);
        if (idx != -1) {
          _notifications[idx]['is_read'] = true;
        }
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final success = await ApiService.markAllNotificationsAsRead();
    if (success && mounted) {
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
        _unreadCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read.')),
      );
    }
  }

  Future<void> _deleteNotification(int id) async {
    final success = await ApiService.deleteNotification(id);
    if (success && mounted) {
      setState(() {
        _notifications.removeWhere((n) => n['id'] == id);
      });
    }
  }

  Future<void> _deleteAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications?'),
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE ALL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteAllNotifications();
      if (success && mounted) {
        setState(() {
          _notifications.clear();
          _unreadCount = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared.')),
        );
      }
    }
  }

  void _onNotificationTap(Map<String, dynamic> item) {
    final int id = item['id'];
    if (item['is_read'] == false) {
      _markAsRead(id);
    }

    final String type = (item['type'] ?? '').toString().toUpperCase();
    final Map<String, dynamic> data = (item['data'] as Map<String, dynamic>?) ?? {};

    if (data['action_url'] != null) {
      Navigator.pushNamed(context, data['action_url'].toString());
      return;
    }

    switch (type) {
      case 'EMERGENCY':
      case 'SOS':
        Navigator.pushNamed(context, '/emergency');
        break;
      case 'CHAT':
        Navigator.pushNamed(context, '/chat');
        break;
      case 'FAMILY':
        Navigator.pushNamed(context, '/family');
        break;
      case 'HEALTH':
      case 'REMINDER':
      case 'MEDICINE':
      case 'WATER':
      case 'SLEEP':
        Navigator.pushNamed(context, '/health');
        break;
      default:
        Navigator.pushNamed(context, '/settings');
        break;
    }
  }

  IconData _getIconForType(String type, String priority) {
    if (priority == 'HIGH' || priority == 'URGENT' || type == 'EMERGENCY' || type == 'SOS') {
      return Icons.notification_important_rounded;
    }
    switch (type) {
      case 'CHAT':
        return Icons.chat_bubble_outline_rounded;
      case 'FAMILY':
        return Icons.people_outline_rounded;
      case 'HEALTH':
      case 'REMINDER':
      case 'MEDICINE':
        return Icons.health_and_safety_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getColorForType(String type, String priority) {
    if (priority == 'HIGH' || priority == 'URGENT' || type == 'EMERGENCY' || type == 'SOS') {
      return Colors.red;
    }
    switch (type) {
      case 'CHAT':
        return const Color(0xFF3B82F6);
      case 'FAMILY':
        return const Color(0xFF14B8A6);
      case 'HEALTH':
      case 'REMINDER':
      case 'MEDICINE':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredList = _notifications.where((item) {
      if (_selectedTab == 'ALL') return true;
      if (_selectedTab == 'UNREAD') return item['is_read'] == false;
      final type = (item['type'] ?? '').toString().toUpperCase();
      if (_selectedTab == 'EMERGENCY') return type == 'EMERGENCY' || type == 'SOS';
      if (_selectedTab == 'FAMILY') return type == 'FAMILY';
      if (_selectedTab == 'CHAT') return type == 'CHAT';
      if (_selectedTab == 'HEALTH') return type == 'HEALTH' || type == 'REMINDER' || type == 'MEDICINE';
      if (_selectedTab == 'SYSTEM') return type == 'SYSTEM';
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Mark All Read',
              onPressed: _markAllAsRead,
            ),
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'mark_all') _markAllAsRead();
                if (value == 'delete_all') _deleteAllNotifications();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'mark_all', child: Text('Mark all as read')),
                const PopupMenuItem(value: 'delete_all', child: Text('Delete all notifications', style: TextStyle(color: Colors.red))),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // SOS Only header label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
              border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notification_important_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Text(
                  'SOS / Emergency Alerts Only',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),

          // Main List View
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF14B8A6),
              onRefresh: _loadNotifications,
              child: _isLoading && _notifications.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
                  : filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.notifications_none_rounded, size: 48, color: Color(0xFF14B8A6)),
                              ),
                              const SizedBox(height: 16),
                              const Text('No notifications found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(
                                'You are all caught up! Live alerts will appear here.',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final item = filteredList[idx];
                            final int id = item['id'];
                            final bool isRead = item['is_read'] == true;
                            final String type = (item['type'] ?? '').toString().toUpperCase();
                            final String priority = (item['priority'] ?? 'NORMAL').toString().toUpperCase();
                            final Color color = _getColorForType(type, priority);

                            return Dismissible(
                              key: Key('notif_$id'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red[400],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteNotification(id),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white)
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isRead
                                        ? (isDark ? Colors.white12 : Colors.grey[200]!)
                                        : const Color(0xFF14B8A6).withValues(alpha: 0.4),
                                    width: isRead ? 1 : 1.5,
                                  ),
                                  boxShadow: isRead
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFF14B8A6).withValues(alpha: 0.08),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(_getIconForType(type, priority), color: color, size: 22),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['title'] ?? '',
                                          style: TextStyle(
                                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF14B8A6),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        item['message'] ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white70 : Colors.grey[700],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item['created_at_formatted'] ?? '',
                                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                          ),
                                          Text(
                                            type,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () => _onNotificationTap(item),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
