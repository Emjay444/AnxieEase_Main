import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _selectedFilter;
  final _dateFormatter = DateFormat('MMM d, y, h:mm a');
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _supabaseService.getNotifications(
        type: _selectedFilter,
      );

      // Calculate unread count
      final unreadCount = notifications.where((n) => !n['read']).length;

      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
        _isLoading = false;
      });

      // Update badge count
      await _notificationService.updateBadgeCount(_unreadCount);
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    if (!notification['read']) {
      try {
        await _supabaseService.markNotificationAsRead(notification['id']);
        setState(() {
          notification['read'] = true;
          _unreadCount = _unreadCount - 1;
        });
        await _notificationService.updateBadgeCount(_unreadCount);
      } catch (e) {
        debugPrint('Error marking notification as read: $e');
      }
    }

    if (!mounted) return;

    // Navigate to the appropriate screen
    switch (notification['related_screen']) {
      case 'alert_log':
        Navigator.pushNamed(context, '/alert_log');
        break;
      case 'metrics':
        Navigator.pushNamed(context, '/metrics');
        break;
      case 'calendar':
        Navigator.pushNamed(context, '/calendar');
        break;
      case 'breathing_screen':
        Navigator.pushNamed(context, '/breathing');
        break;
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _supabaseService.deleteNotification(id, hardDelete: true);
      setState(() {
        _notifications.removeWhere((notification) => notification['id'] == id);
        // Update unread count if needed
        _unreadCount = _notifications.where((n) => !n['read']).length;
      });
      await _notificationService.updateBadgeCount(_unreadCount);

      // Only notify home screen of changes, don't navigate back
      if (mounted) {
        // Send a message to home screen to refresh its notifications
        Navigator.of(context).pop(true);
        // Re-push the notifications screen to maintain state
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotificationsScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notification: $e')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear All Notifications'),
            content:
                const Text('Are you sure you want to clear all notifications?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear All'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await _supabaseService.clearAllNotifications(hardDelete: true);
        setState(() {
          _notifications.clear();
          _unreadCount = 0;
        });
        await _notificationService.updateBadgeCount(0);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications cleared successfully'),
              duration: Duration(seconds: 2),
            ),
          );

          // Only notify home screen of changes, don't navigate back
          Navigator.of(context).pop(true);
          // Re-push the notifications screen to maintain state
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsScreen(),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing notifications: $e')),
          );
        }
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      setState(() => _isLoading = true);
      await _supabaseService.markAllNotificationsAsRead();
      await _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking notifications as read: $e')),
        );
      }
    }
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final DateTime createdAt = DateTime.parse(notification['created_at']);
    final String timeAgo = timeago.format(createdAt);
    final String formattedDate = _dateFormatter.format(createdAt);
    final bool isRead = notification['read'] ?? false;

    return Dismissible(
      key: Key(notification['id']),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(notification['id']),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text(
                'Are you sure you want to delete this notification?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      child: ListTile(
        leading: Stack(
          children: [
            _getNotificationIcon(notification['type']),
            if (!isRead)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          notification['title'],
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['message']),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  timeAgo,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    switch (type) {
      case 'alert':
        return const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.warning, color: Colors.white),
        );
      case 'reminder':
        return const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.notifications_active, color: Colors.white),
        );
      case 'log':
        return const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.check_circle, color: Colors.white),
        );
      default:
        return const CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.notifications, color: Colors.white),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (String value) {
              setState(() {
                _selectedFilter = value == 'all' ? null : value;
              });
              _loadNotifications();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All'),
              ),
              const PopupMenuItem(
                value: 'alert',
                child: Text('Alerts'),
              ),
              const PopupMenuItem(
                value: 'reminder',
                child: Text('Reminders'),
              ),
              const PopupMenuItem(
                value: 'log',
                child: Text('Logs'),
              ),
            ],
          ),
          if (_notifications.any((n) => !n['read']))
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllNotifications,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _buildNotificationItem(_notifications[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Notifications Yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You will see notifications here when they arrive',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_selectedFilter != null)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedFilter = null;
                });
                _loadNotifications();
              },
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Reset Filter'),
            ),
        ],
      ),
    );
  }
}
