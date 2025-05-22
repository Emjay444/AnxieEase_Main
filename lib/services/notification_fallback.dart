import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:timezone/data/latest.dart' as tz;

class NotificationFallback with ChangeNotifier {
  String _currentSeverity = 'unknown';

  String get currentSeverity => _currentSeverity;

  // Initialize the notification plugin
  Future<void> initialize() async {
    tz.initializeTimeZones();

    // Initialize awesome_notifications
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'anxiety_alerts',
          channelName: 'Anxiety Alerts',
          channelDescription: 'Notifications for anxiety level alerts',
          defaultColor: Colors.red,
          importance: NotificationImportance.High,
          ledColor: Colors.white,
        ),
        NotificationChannel(
          channelKey: 'basic_channel',
          channelName: 'Basic Notifications',
          channelDescription: 'Basic notification tests',
          defaultColor: Colors.blue,
          importance: NotificationImportance.High,
          enableVibration: true,
        ),
      ],
    );

    // Request permission
    await _requestPermissions();
  }

  // Request notification permissions
  Future<bool> _requestPermissions() async {
    return await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  // Initialize Firebase listener for anxiety severity
  void initializeListener(DatabaseReference ref) {
    ref.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      final severity = data['severity']?.toString().toLowerCase();
      final heartRate = data['heartRate'];
      final temperature = data['temperature'];

      if (severity == null) return;

      _currentSeverity = severity;
      notifyListeners();

      String title = '';
      String body = '';
      Color color;

      switch (severity) {
        case 'mild':
          title = '🟢 Mild Alert';
          body =
              'Slight elevation in readings. Temp: $temperature°C, HR: $heartRate bpm';
          color = Colors.green;
          break;
        case 'moderate':
          title = '🟠 Moderate Alert';
          body =
              'Noticeable symptoms detected. Temp: $temperature°C, HR: $heartRate bpm';
          color = Colors.orange;
          break;
        case 'severe':
          title = '🔴 Severe Alert';
          body = 'URGENT: High risk! Temp: $temperature°C, HR: $heartRate bpm';
          color = Colors.red;
          break;
        default:
          return;
      }

      _showNotification(title, body, color);
    });
  }

  // Show a notification with the provided title and body
  Future<void> _showNotification(String title, String body, Color color) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'anxiety_alerts',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        color: color,
      ),
    );
  }

  // Method to manually trigger a notification based on current severity
  void sendManualNotification() {
    String title = '';
    String body = '';
    Color color;

    switch (_currentSeverity) {
      case 'mild':
        title = '🟢 Mild Alert (Manual)';
        body = 'Slight elevation in anxiety readings detected.';
        color = Colors.green;
        break;
      case 'moderate':
        title = '🟠 Moderate Alert (Manual)';
        body = 'Moderate anxiety symptoms detected.';
        color = Colors.orange;
        break;
      case 'severe':
        title = '🔴 Severe Alert (Manual)';
        body = 'URGENT: High anxiety levels detected!';
        color = Colors.red;
        break;
      default:
        title = 'Status Update';
        body = 'Current status: $_currentSeverity';
        color = Colors.grey;
    }

    _showNotification(title, body, color);
  }

  // Send a test notification
  Future<void> sendTestNotification() async {
    await _showNotification(
      '🧪 Test Notification',
      'This is a test notification from AnxieEase',
      Colors.blue,
    );
  }
}
