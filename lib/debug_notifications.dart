import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'services/notification_service.dart';
import 'package:intl/intl.dart';

class NotificationDebugScreen extends StatefulWidget {
  @override
  _NotificationDebugScreenState createState() =>
      _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  List<String> _debugLogs = [];
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _addLog('Debug screen initialized');
    _checkCurrentTime();
    _listScheduledNotifications();
  }

  void _addLog(String message) {
    setState(() {
      final timestamp =
          DateFormat('MMM dd, yyyy h:mm a').format(DateTime.now());
      _debugLogs.insert(0, '[$timestamp] $message');
    });
    print('🐛 $message');
  }

  void _checkCurrentTime() {
    final deviceTime = DateTime.now();
    final utcTime = DateTime.now().toUtc();

    _addLog('Device local time: ${deviceTime.toString()}');
    _addLog('UTC time: ${utcTime.toString()}');
    _addLog('Device timezone offset: ${deviceTime.timeZoneOffset}');
  }

  Future<void> _listScheduledNotifications() async {
    try {
      final scheduled =
          await AwesomeNotifications().listScheduledNotifications();
      _addLog('Found ${scheduled.length} scheduled notifications');

      for (var notification in scheduled) {
        _addLog(
            'Scheduled: ${notification.content?.title} at ${notification.schedule?.toString()}');
      }
    } catch (e) {
      _addLog('Error listing scheduled notifications: $e');
    }
  }

  Future<void> _scheduleTestNotification() async {
    try {
      await _notificationService.initialize();

      // Schedule a test notification 1 minute from now
      final scheduleTime = DateTime.now().add(Duration(minutes: 1));

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'wellness_reminders',
          title: 'Test Wellness Reminder',
          body:
              'This is a test notification scheduled for ${scheduleTime.toString()}',
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar(
          hour: scheduleTime.hour,
          minute: scheduleTime.minute,
          second: scheduleTime.second,
          repeats: false,
        ),
      );

      _addLog('Test notification scheduled for: ${scheduleTime.toString()}');
    } catch (e) {
      _addLog('Error scheduling test notification: $e');
    }
  }

  Future<void> _showImmediateNotification() async {
    try {
      await _notificationService.initialize();

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'wellness_reminders',
          title: 'Immediate Test Notification',
          body:
              'Sent at ${DateFormat('MMM dd, yyyy h:mm a').format(DateTime.now())}',
          notificationLayout: NotificationLayout.Default,
        ),
      );

      _addLog('Immediate notification sent');
    } catch (e) {
      _addLog('Error sending immediate notification: $e');
    }
  }

  Future<void> _cancelAllNotifications() async {
    try {
      await AwesomeNotifications().cancelAll();
      _addLog('All notifications cancelled');
      _listScheduledNotifications();
    } catch (e) {
      _addLog('Error cancelling notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Debug'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _checkCurrentTime,
                  child: Text('Check Time'),
                ),
                ElevatedButton(
                  onPressed: _listScheduledNotifications,
                  child: Text('List Scheduled'),
                ),
                ElevatedButton(
                  onPressed: _scheduleTestNotification,
                  child: Text('Test in 1min'),
                ),
                ElevatedButton(
                  onPressed: _showImmediateNotification,
                  child: Text('Send Now'),
                ),
                ElevatedButton(
                  onPressed: _cancelAllNotifications,
                  child: Text('Cancel All'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _debugLogs.length,
              itemBuilder: (context, index) {
                return Container(
                  padding: EdgeInsets.all(8),
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _debugLogs[index],
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
