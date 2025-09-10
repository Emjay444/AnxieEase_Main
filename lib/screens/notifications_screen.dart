import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/notification_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../search.dart';

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

  // Color utilities for nicer gradients/contrast
  Color _lighten(Color c, [double amount = 0.08]) {
    final hsl = HSLColor.fromColor(c);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }

  Color _darken(Color c, [double amount = 0.08]) {
    final hsl = HSLColor.fromColor(c);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  // Derive a severity color from the notification title markers/keywords
  Color _severityColorFromTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('🔴') || t.contains('severe')) return Colors.red;
    if (t.contains('🟠') || t.contains('moderate')) return Colors.orange;
    if (t.contains('🟢') || t.contains('mild')) return Colors.green;
    return Colors.red; // default for generic alerts
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

    // Show notification details modal instead of just navigating
    _showNotificationDetails(
      notification['title'],
      notification['message'],
      _getDisplayTime(notification['created_at']),
      notification['type'] ?? 'info',
      notification,
    );
  }

  String _getDisplayTime(String createdAt) {
    final DateTime date = DateTime.parse(createdAt);
    final String timeAgo = timeago.format(date);
    return timeAgo;
  }

  // Add a method to show notification details
  void _showNotificationDetails(String title, String message, String time,
      String type, Map<String, dynamic> notification) {
    final bool isSevere = title.contains('Severe') || title.contains('🔴');
    Color getTypeColor() {
      switch (type) {
        case 'warning':
          return Colors.orange;
        case 'alert':
          return _severityColorFromTitle(title);
        case 'log':
          return Colors.green;
        case 'info':
        case 'reminder':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    IconData getTypeIcon() {
      switch (type) {
        case 'warning':
        case 'alert':
          return Icons.warning;
        case 'log':
          return Icons.check_circle;
        case 'info':
        case 'reminder':
          return Icons.notifications;
        default:
          return Icons.notifications;
      }
    }

  // (Removed unused severity label helper)

    String getRecommendation() {
      if (title.contains('Mood Pattern')) {
        return 'Consider using calming exercises to help manage anxiety when feeling anxious or fearful.';
      } else if (title.contains('High Stress')) {
        return 'Try breathing exercises to help reduce stress levels and promote relaxation.';
      } else if (title.contains('Symptom')) {
        return 'Monitor your symptoms and use appropriate techniques to manage your anxiety.';
      } else {
        return 'Consider using the breathing exercises and other tools available in the app.';
      }
    }

    List<String> getActionItems() {
      if (title.contains('Mood Pattern')) {
        return [
          'Use breathing exercises',
          'Practice mindfulness meditation',
          'Record your triggers in journal',
          'Try progressive muscle relaxation'
        ];
      } else if (title.contains('High Stress')) {
        return [
          'Practice 4-7-8 breathing technique',
          'Take a short break from current activities',
          'Use guided meditation',
          'Find a quiet space to relax'
        ];
      } else if (title.contains('Symptom')) {
        return [
          'Track your symptoms in the journal',
          'Use appropriate breathing techniques',
          'Consider relaxation exercises',
          'Monitor changes in symptoms'
        ];
      } else {
        return [
          'Use breathing exercises',
          'Monitor symptoms',
          'Practice self-care activities',
          'Use the app resources'
        ];
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final accent = getTypeColor();
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Modern Curved Gradient Header (no top white part)
                  ClipPath(
                    clipper: _HeaderClipper(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _darken(accent, 0.06),
                            _lighten(accent, 0.06),
                          ],
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Slight scale-in animation for the icon tile
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            tween: Tween(begin: 0.9, end: 1),
                            builder: (context, scale, child) => Transform.scale(
                              scale: scale,
                              child: child,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                getTypeIcon(),
                                color: _darken(accent, 0.15),
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Text(
                                      time,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (type.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(28),
                                          border: Border.all(color: Colors.white.withOpacity(0.35)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.circle, size: 8, color: Colors.white),
                                            const SizedBox(width: 6),
                                            Text(
                                              type[0].toUpperCase() + type.substring(1),
                                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Details Section with copy
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E2432),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy',
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                color: Colors.grey[700],
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: message));
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Message copied to clipboard')),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Text(
                              message,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Recommendation Section with accent styling
                          const Text(
                            'Recommendation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2432),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accent.withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lightbulb_outline, color: accent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    getRecommendation(),
                                    style: TextStyle(
                                      color: Colors.grey[900],
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Safety plan / Action Items Section
                          Text(
                            isSevere ? 'Safety Plan' : 'Suggested Actions',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2432),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isSevere) _buildSafetyContacts(context),
                          if (isSevere) const SizedBox(height: 12),

                          // Modern chips for actions
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: getActionItems()
                                .map((action) => _buildActionChip(action, _darken(accent, 0.1)))
                                .toList(),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Action Button footer
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                            if (isSevere) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SearchScreen(),
                                ),
                              );
                            } else {
                              Navigator.pushNamed(context, '/breathing');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSevere ? Colors.red.shade700 : _darken(accent, 0.05),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isSevere ? 'Find Nearby Clinics' : 'Try Breathing Exercise',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Modern action chip for action items
  Widget _buildActionChip(String label, Color accent) {
    return InkWell(
      onTap: () => HapticFeedback.selectionClick(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: accent, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E2432),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build emergency contacts block for severe alerts
  Widget _buildSafetyContacts(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    final String? userEmergency = user?.emergencyContact;

    Widget callChip(String label, String number) {
      return InkWell(
        onTap: () => _callNumber(number),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call, color: Colors.red),
              const SizedBox(width: 8),
              Text('$label: $number', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Emergency Contacts',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (userEmergency != null && userEmergency.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: callChip('Your contact', userEmergency.trim()),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'No personal emergency contact set. Add one in Profile.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          callChip('NCMH Crisis Hotline', '1553'),
          const SizedBox(height: 8),
          callChip('Smart/TNT', '0919-057-1553'),
          const SizedBox(height: 8),
          callChip('Globe/TM', '0917-899-8727'),
        ],
      ),
    );
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot place call to $number')),
        );
      }
    }
  }

  // (Removed unused related screen navigator)

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

  // Build a modern notification card
  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final DateTime createdAt = DateTime.parse(notification['created_at']);
    final String timeAgo = timeago.format(createdAt);
    final String formattedDate = _dateFormatter.format(createdAt);
    final bool isRead = notification['read'] ?? false;
    final String title = notification['title'] ?? '';
    final String type = notification['type'] ?? '';

    // Check if this is a reminder notification that should not have a popup modal
    bool isReminder = type == 'reminder' ||
        title.contains('Anxiety Check-in') ||
        title.contains('Anxiety Prevention') ||
        title.contains('Wellness Reminder') ||
        title.contains('Mental Health Moment') ||
        title.contains('Relaxation Reminder');

    final Color accent = () {
      switch (type) {
        case 'alert':
          return _severityColorFromTitle(title);
        case 'reminder':
          return Colors.blue;
        case 'log':
          return Colors.green;
        default:
          return Colors.teal;
      }
    }();

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
      child: InkWell(
        onTap: isReminder
            ? (!isRead ? () => _markNotificationAsRead(notification) : null)
            : () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isRead ? Colors.white : Colors.teal.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRead
                    ? Colors.grey.withOpacity(0.15)
                    : accent.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leading icon with subtle background
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(child: _getNotificationIcon(type, accent)),
                      if (!isRead)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                color: const Color(0xFF1E2432),
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (!isReminder)
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.grey[400],
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification['message'],
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }

  Widget _getNotificationIcon(String type, Color accent) {
    switch (type) {
      case 'alert':
        return Icon(Icons.warning_rounded, color: accent, size: 24);
      case 'reminder':
        return Icon(Icons.notifications_active, color: accent, size: 24);
      case 'log':
        return Icon(Icons.check_circle, color: accent, size: 24);
      default:
        return Icon(Icons.notifications, color: accent, size: 24);
    }
  }

  // Add a method to just mark notifications as read without showing details
  Future<void> _markNotificationAsRead(
      Map<String, dynamic> notification) async {
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
  }

  // Group notifications by date (Today, Yesterday, Older)
  Map<String, List<Map<String, dynamic>>> _groupNotifications() {
    final Map<String, List<Map<String, dynamic>>> groups = {
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };
    final now = DateTime.now();
    for (final n in _notifications) {
      final created = DateTime.parse(n['created_at']);
      final difference = now.difference(created).inDays;
      if (difference == 0) {
        groups['Today']!.add(n);
      } else if (difference == 1) {
        groups['Yesterday']!.add(n);
      } else {
        groups['Earlier']!.add(n);
      }
    }
    // Remove empty groups
    groups.removeWhere((k, v) => v.isEmpty);
    return groups;
  }

  Widget _buildFilterChips() {
    final filters = ['all', 'alert', 'reminder', 'log'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((f) {
          final selected = (_selectedFilter ?? 'all') == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                f == 'all'
                    ? 'All'
                    : f[0].toUpperCase() + f.substring(1) + (f == 'log' ? 's' : ''),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? Colors.white : Colors.grey[700],
                ),
              ),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedFilter = f == 'all' ? null : f);
                _loadNotifications();
                HapticFeedback.selectionClick();
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.teal[600],
              elevation: selected ? 2 : 0,
              pressElevation: 0,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupNotifications();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
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
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
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
      body: Column(
        children: [
          const SizedBox(height: 8),
            _buildFilterChips(),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: grouped.entries.length,
                          itemBuilder: (context, groupIndex) {
                            final entry = grouped.entries.elementAt(groupIndex);
                            final groupLabel = entry.key;
                            final items = entry.value;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                                  child: Text(
                                    groupLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                ...items.map(_buildNotificationItem).toList(),
                              ],
                            );
                          },
                        ),
            ),
          ),
        ],
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

// Curved header clipper to remove flat white top and add modern curve
class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 24);
    // Smooth curve at the bottom of header
    path.quadraticBezierTo(
      size.width * 0.5, size.height,
      size.width, size.height - 24,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
